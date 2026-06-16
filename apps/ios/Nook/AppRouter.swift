import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Supabase
import SwiftUI

enum AppScreen: Hashable {
    case intro
    case welcome
    case profileSetup
    case onboarding
    case home
}

@MainActor
@Observable
final class AppRouter {
    var currentScreen: AppScreen = .intro
    var isLoading = true

    // Current user profile — shared across all views
    var currentUserAvatarURL: URL?
    var currentUserDisplayName: String = ""
    var currentUserUsername: String = ""

    private var authListenerTask: Task<Void, Never>?

    func startListening() {
        authListenerTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    if session != nil {
                        await navigateAfterAuth()
                    } else {
                        currentScreen = .intro
                    }
                    isLoading = false
                case .signedIn:
                    await navigateAfterAuth()
                case .signedOut:
                    currentScreen = .intro
                case .tokenRefreshed, .userUpdated, .userDeleted,
                     .passwordRecovery, .mfaChallengeVerified:
                    break
                }
            }
        }
    }

    private func navigateAfterAuth() async {
        let hasOnboarded = await checkOnboardingCompleted()
        if hasOnboarded {
            await loadCurrentUserProfile()
            currentScreen = .home
        } else {
            // New / mid-onboarding user. Resume where they left off: if they've
            // already picked a username (profile step done) jump straight to
            // interests, otherwise start at the welcome → profile flow.
            let hasUsername = await hasUsernameSet()
            currentScreen = hasUsername ? .onboarding : .welcome
        }
        await registerForPush()
    }

    /// Ask for notification permission (prompts only the first time) / refresh the
    /// APNs token, then sync it to `device_tokens` for the now-authenticated user.
    private func registerForPush() async {
        await PushService.shared.requestAuthorizationAndRegister()
        await PushService.shared.uploadCachedTokenIfAvailable()
    }

    private func hasUsernameSet() async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else { return false }
        guard let profile = try? await ProfileService().getProfile(userId: userId) else { return false }
        return (profile.username?.isEmpty == false)
    }

    func continueFromWelcome() {
        currentScreen = .profileSetup
    }

    private func checkOnboardingCompleted() async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            return false
        }

        struct ProfileRow: Decodable {
            let onboarding_completed: Bool
        }

        do {
            let row: ProfileRow = try await supabase
                .from("user_profiles")
                .select("onboarding_completed")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return row.onboarding_completed
        } catch {
            return false
        }
    }

    func saveInterests(_ interests: Set<String>) async throws {
        let userId = try await supabase.auth.session.user.id

        struct ProfileUpsert: Encodable {
            let id: String
            let interests: [String]
            let onboarding_completed: Bool
        }

        try await supabase
            .from("user_profiles")
            .upsert(ProfileUpsert(
                id: userId.uuidString,
                interests: Array(interests).sorted(),
                onboarding_completed: true
            ))
            .execute()

        // Load the shared profile fields before showing home. The onboarding-resume
        // path (username already set → routed straight to interests) never calls
        // loadCurrentUserProfile, so without this the home/profile surfaces would
        // render an empty avatar and "Nook User" even though the DB has the data.
        await loadCurrentUserProfile()
        currentScreen = .home
    }

    /// Persists the onboarding profile step (display name + username + avatar)
    /// and advances to the interests step. The row is upserted so it works
    /// whether or not a `user_profiles` row already exists, and `avatar_url` is
    /// only written when we actually have one (so we never null out a social
    /// avatar). Throws on a username uniqueness violation so the caller can
    /// surface it.
    func saveProfileSetup(displayName: String, username: String, avatarImageData: Data?) async throws {
        let user = try await supabase.auth.session.user
        let userId = user.id

        // A freshly-cropped image wins; otherwise back-fill the social avatar.
        var avatarURLString: String?
        if let avatarImageData {
            let url = try await StorageService().uploadAvatar(userId: userId, imageData: avatarImageData)
            avatarURLString = url.absoluteString
        } else if let socialURL = user.userMetadata["avatar_url"]?.value as? String {
            avatarURLString = Self.highResAvatarURL(socialURL)
        }

        // Routed through the moderation gateway: full_name / username (and the
        // avatar image) are screened before they're persisted. A nil avatar URL
        // is omitted so an existing avatar isn't overwritten. A taken username
        // comes back as an AppError the caller surfaces.
        struct ProfileSetupPayload: Encodable, Sendable {
            let full_name: String
            let username: String
            let avatar_url: String?
        }

        let _: ContentIdResponse = try await APIClient().content("update_profile_text", ProfileSetupPayload(
            full_name: displayName,
            username: username,
            avatar_url: avatarURLString
        ))

        // Keep auth metadata's display name in sync (used as a fallback in
        // places that read it directly).
        _ = try? await supabase.auth.update(
            user: UserAttributes(data: ["full_name": .string(displayName)])
        )

        // Prime the shared user fields so the rest of the app shows them
        // immediately once onboarding finishes.
        currentUserDisplayName = displayName
        currentUserUsername = "@\(username)"
        if let avatarURLString {
            currentUserAvatarURL = URL(string: avatarURLString)
        }

        currentScreen = .onboarding
    }

    func loadCurrentUserProfile() async {
        guard let user = try? await supabase.auth.session.user else { return }

        let profileService = ProfileService()
        if let data = try? await profileService.getProfile(userId: user.id) {
            currentUserDisplayName = data.fullName
                ?? (user.userMetadata["full_name"]?.value as? String)
                ?? "User"
            currentUserUsername = data.username.map { "@\($0)" } ?? ""

            if let dbAvatar = data.avatarURL {
                currentUserAvatarURL = dbAvatar
            } else if let socialURL = (user.userMetadata["avatar_url"]?.value as? String) {
                // Backfill social avatar to DB so it shows on reviews, comments, etc.
                let highRes = Self.highResAvatarURL(socialURL)
                currentUserAvatarURL = URL(string: highRes)
                try? await profileService.updateProfile(userId: user.id, avatarURL: highRes)
            }
        } else {
            currentUserDisplayName = (user.userMetadata["full_name"]?.value as? String) ?? "User"
            if let urlString = user.userMetadata["avatar_url"]?.value as? String {
                currentUserAvatarURL = URL(string: Self.highResAvatarURL(urlString))
            }
        }
    }

    func refreshProfile() async {
        await loadCurrentUserProfile()
    }

    nonisolated static func highResAvatarURL(_ urlString: String) -> String {
        guard urlString.contains("googleusercontent.com") else { return urlString }
        if let range = urlString.range(of: #"=s\d+-c"#, options: .regularExpression) {
            return urlString.replacingCharacters(in: range, with: "=s400-c")
        }
        return urlString
    }

    /// Derives a valid default username from an email's local-part, conforming
    /// to the `^[a-zA-Z0-9_]{3,20}$` rule the DB enforces: lowercased,
    /// separators collapsed to underscores, anything else stripped, padded to
    /// at least 3 chars and capped at 20. Uniqueness is handled separately.
    nonisolated static func suggestedUsername(fromEmail email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "nook"
        var slug = local.lowercased()

        // Turn runs of unsupported characters into a single underscore...
        slug = slug.replacingOccurrences(of: "[^a-z0-9_]+", with: "_", options: .regularExpression)
        // ...collapse repeats, then trim stray edge underscores.
        slug = slug.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        if slug.count > 20 {
            slug = String(slug.prefix(20)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }

        if slug.count < 3 {
            let padding = (0..<max(3 - slug.count, 2)).map { _ in String(Int.random(in: 0...9)) }.joined()
            slug = String((slug + padding).prefix(20))
        }

        return slug
    }

    func signInWithOTP(email: String) async throws {
        try await supabase.auth.signInWithOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        try await supabase.auth.verifyOTP(email: email, token: token, type: .email)
    }

    func resendOTP(email: String) async throws {
        try await supabase.auth.signInWithOTP(email: email)
    }

    func signInWithApple(_ authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }
        guard let identityToken = credential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8)
        else {
            throw AuthError.missingToken
        }

        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )

        if let fullName = credential.fullName?.formatted(), !fullName.isEmpty {
            _ = try? await supabase.auth.update(
                user: UserAttributes(data: ["full_name": .string(fullName)])
            )
            // Also save to user_profiles
            if let userId = try? await supabase.auth.session.user.id {
                let profileService = ProfileService()
                try? await profileService.updateProfile(userId: userId, fullName: fullName)
            }
        }
    }

    func signInWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            throw AuthError.missingRootViewController
        }

        let rawNonce = UUID().uuidString
        let hashedNonce = SHA256.hash(data: Data(rawNonce.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: nil,
            nonce: hashedNonce
        )

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }

        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                nonce: rawNonce
            )
        )

        // Save Google display name to user_profiles
        if let fullName = result.user.profile?.name, !fullName.isEmpty {
            _ = try? await supabase.auth.update(
                user: UserAttributes(data: ["full_name": .string(fullName)])
            )
            if let userId = try? await supabase.auth.session.user.id {
                let profileService = ProfileService()
                try? await profileService.updateProfile(userId: userId, fullName: fullName)
            }
        }
    }

    func signOut() async throws {
        // Remove this device's token first, while RLS still allows it (auth.uid()).
        await PushService.shared.clearCurrentDeviceToken()
        try await supabase.auth.signOut()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case missingToken
    case missingRootViewController

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Invalid Apple credential."
        case .missingToken: "Could not retrieve identity token."
        case .missingRootViewController: "Unable to present sign-in."
        }
    }
}
