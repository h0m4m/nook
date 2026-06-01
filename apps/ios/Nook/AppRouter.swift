import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Supabase
import SwiftUI

enum AppScreen: Hashable {
    case intro
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
        }
        currentScreen = hasOnboarded ? .home : .onboarding
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

        currentScreen = .home
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

    private static func highResAvatarURL(_ urlString: String) -> String {
        guard urlString.contains("googleusercontent.com") else { return urlString }
        if let range = urlString.range(of: #"=s\d+-c"#, options: .regularExpression) {
            return urlString.replacingCharacters(in: range, with: "=s400-c")
        }
        return urlString
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
