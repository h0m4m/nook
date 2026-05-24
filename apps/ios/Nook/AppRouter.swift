import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Supabase
import SwiftUI

enum AppScreen: Hashable {
    case intro
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
