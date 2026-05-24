import AuthenticationServices
import SwiftUI

struct IntroView: View {
    var router: AppRouter

    @State private var showEmailEntry = false

    var body: some View {
        ZStack {
            Color.nook.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero illustration
                heroIllustration
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Bottom auth container
                IntroAuthButtons(router: router, showEmailEntry: $showEmailEntry)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

        }
        .sheet(isPresented: $showEmailEntry) {
            EmailEntryOverlay(
                router: router,
                isPresented: $showEmailEntry
            )
        }
    }

    // MARK: - Hero Illustration (placeholder)

    private var heroIllustration: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.nook.secondary)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.nook.mutedForeground.opacity(0.3))
            )
    }
}

// MARK: - Auth Buttons

private enum SocialProvider {
    case apple, google
}

private struct IntroAuthButtons: View {
    let router: AppRouter
    @Binding var showEmailEntry: Bool

    @State private var loadingProvider: SocialProvider?
    @State private var errorMessage: String?
    @State private var appleSignInDelegate: AppleSignInDelegate?

    private var isLoading: Bool { loadingProvider != nil }

    var body: some View {
        VStack(spacing: 12) {
            // Continue with Google
            SocialButton(
                label: "Continue with Google",
                isLoading: loadingProvider == .google
            ) {
                Image("google-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } action: {
                handleGoogle()
            }
            .disabled(isLoading)

            // Continue with Apple
            SocialButton(
                label: "Continue with Apple",
                isLoading: loadingProvider == .apple
            ) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.nook.foreground)
            } action: {
                startAppleSignIn()
            }
            .disabled(isLoading)

            // Continue with Email
            SocialButton(
                label: "Continue with Email",
                isLoading: false
            ) {
                Image(systemName: "envelope")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.nook.foreground)
            } action: {
                showEmailEntry = true
            }
            .disabled(isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private func startAppleSignIn() {
        loadingProvider = .apple
        errorMessage = nil

        let delegate = AppleSignInDelegate { result in
            switch result {
            case .success(let authorization):
                Task {
                    do {
                        try await router.signInWithApple(authorization)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    loadingProvider = nil
                }
            case .failure(let error):
                if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                    errorMessage = error.localizedDescription
                }
                loadingProvider = nil
            }
        }
        appleSignInDelegate = delegate

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    private func handleGoogle() {
        loadingProvider = .google
        errorMessage = nil
        Task {
            do {
                try await router.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
            loadingProvider = nil
        }
    }
}

// MARK: - Shared Social Button

private struct SocialButton<Icon: View>: View {
    let label: String
    let isLoading: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(Color.nook.primary)
                        .frame(width: 20, height: 20)
                } else {
                    icon()
                        .frame(width: 20, height: 20)
                }

                Text(label)
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.foreground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            .overlay(
                RoundedRectangle(cornerRadius: NookRadii.sm)
                    .strokeBorder(Color.nook.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Email Entry Overlay

private struct EmailEntryOverlay: View {
    let router: AppRouter
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.nook.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with back button
                        HStack {
                            Button {
                                isPresented = false
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.nook.foreground)
                            }

                            Spacer()
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Continue with email")
                                .font(.custom("PlusJakartaSans-Bold", size: 30))
                                .lineSpacing(6)
                                .foregroundStyle(Color.nook.foreground)

                            Text("Sign up or sign in with your email.\nWe'll send you a verification code.")
                                .font(NookFont.bodyMedium)
                                .lineSpacing(4)
                                .foregroundStyle(Color.nook.mutedForeground)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)
                        .padding(.horizontal, 24)

                        // Email field
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email Address")
                                    .font(NookFont.labelSmall)
                                    .foregroundStyle(Color.nook.mutedForeground)
                                    .padding(.leading, 8)

                                NookTextField(
                                    placeholder: "name@example.com",
                                    text: $email,
                                    icon: "envelope"
                                )
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(NookFont.bodySmall)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 12)
                            }

                            Spacer().frame(height: 32)

                            Button {
                                submit()
                            } label: {
                                Group {
                                    if isLoading {
                                        ProgressView()
                                            .tint(Color.white)
                                    } else {
                                        Text("Continue")
                                    }
                                }
                                .font(NookFont.label)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isFormValid ? Color.nook.primary : Color.nook.primary.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(
                                    color: Color.nook.primary.opacity(0.1),
                                    radius: 7.5,
                                    x: 0,
                                    y: 5
                                )
                                .shadow(
                                    color: Color.nook.primary.opacity(0.1),
                                    radius: 3,
                                    x: 0,
                                    y: 2
                                )
                            }
                            .disabled(!isFormValid || isLoading)
                        }
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await router.signInWithOTP(email: trimmedEmail)
                isPresented = false
                router.currentScreen = .emailConfirmation(email: trimmedEmail)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Apple Sign In Delegate

private final class AppleSignInDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private let completion: (Result<ASAuthorization, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }!
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        completion(.success(authorization))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completion(.failure(error))
    }
}

#Preview {
    IntroView(router: AppRouter())
}
