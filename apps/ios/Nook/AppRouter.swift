import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Supabase
import SwiftUI

enum AppScreen: Hashable {
    case intro
    case signIn
    case signUp
    case emailConfirmation(email: String)
    case home
}

@MainActor
@Observable
final class AppRouter {
    var currentScreen: AppScreen = .intro
    var isLoading = true

    private var authListenerTask: Task<Void, Never>?

    func startListening() {
        authListenerTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    currentScreen = session != nil ? .home : .intro
                    isLoading = false
                case .signedIn:
                    currentScreen = .home
                case .signedOut:
                    currentScreen = .intro
                case .tokenRefreshed, .userUpdated, .userDeleted,
                     .passwordRecovery, .mfaChallengeVerified:
                    break
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    /// Returns `true` if email confirmation is required.
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await supabase.auth.signUp(email: email, password: password)
        switch response {
        case .session:
            return false
        case .user(let user):
            // Supabase returns a user with empty identities when the email
            // is already taken (obfuscated for security — no provider info leaked).
            if user.identities?.isEmpty == true {
                throw AuthError.accountExists
            }
            return true
        }
    }

    func verifyOTP(email: String, token: String) async throws {
        try await supabase.auth.verifyOTP(email: email, token: token, type: .signup)
    }

    func resendConfirmation(email: String) async throws {
        try await supabase.auth.resend(email: email, type: .signup)
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
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case missingToken
    case missingRootViewController
    case accountExists

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Invalid Apple credential."
        case .missingToken: "Could not retrieve identity token."
        case .missingRootViewController: "Unable to present sign-in."
        case .accountExists:
            "An account may already exist with this email. Try signing in with email, Google, or Apple."
        }
    }
}
