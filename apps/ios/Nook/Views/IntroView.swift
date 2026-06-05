import AuthenticationServices
import SwiftUI

struct IntroView: View {
    var router: AppRouter

    @State private var showEmailFlow = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Hero — edge-to-edge behind status bar
            heroIllustration
                .ignoresSafeArea()

            // Bottom auth panel
            VStack(spacing: 12) {
                IntroAuthButtons(router: router, showEmailFlow: $showEmailFlow)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .sheet(isPresented: $showEmailFlow) {
            EmailAuthFlow(router: router)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Hero Illustration (placeholder)

    /// The hero art (1080×1620, a 2:3 region) is pinned to the top of the screen,
    /// full-bleed on the sides; its bottom ~5% tucks behind the white auth card.
    private var heroIllustration: some View {
        Color.nook.secondary
            .overlay(alignment: .top) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        Image("authHero")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            }
    }
}

// MARK: - Email Auth Flow (sheet content)

private enum EmailFlowStep {
    case email
    case otp(email: String)
}

private struct EmailAuthFlow: View {
    let router: AppRouter

    @State private var step: EmailFlowStep = .email

    var body: some View {
        ZStack {
            switch step {
            case .email:
                EmailEntryStep(router: router) { email in
                    withAnimation(.easeOut(duration: 0.25)) {
                        step = .otp(email: email)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .otp(let email):
                OTPEntryStep(router: router, email: email)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .background(Color.white)
    }
}

// MARK: - Email Entry Step

private struct EmailEntryStep: View {
    let router: AppRouter
    let onCodeSent: (String) -> Void

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue with email")
                    .font(.custom("PlusJakartaSans-Bold", size: 28))
                    .foregroundStyle(Color.nook.foreground)

                Text("Sign up or sign in with your email.\nWe'll send you a verification code.")
                    .font(NookFont.bodyMedium)
                    .lineSpacing(4)
                    .foregroundStyle(Color.nook.mutedForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 48)
            .padding(.horizontal, 24)

            Spacer()

            // Email field — vertically centered
            VStack(alignment: .leading, spacing: 4) {
                NookTextField(
                    placeholder: "Email address",
                    text: $email,
                    icon: "envelope"
                )
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)

                if let errorMessage {
                    Text(errorMessage)
                        .font(NookFont.bodySmall)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button — anchored to bottom
            Button {
                submit()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .font(NookFont.label)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isFormValid ? Color.nook.primary : Color.nook.primary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!isFormValid || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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
                onCodeSent(trimmedEmail)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - OTP Entry Step

private struct OTPEntryStep: View {
    let router: AppRouter
    let email: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0
    @State private var showResendConfirmation = false

    @FocusState private var isFocused: Bool

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter code")
                    .font(.custom("PlusJakartaSans-Bold", size: 28))
                    .foregroundStyle(Color.nook.foreground)

                Text("Code sent to \(email)")
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color.nook.mutedForeground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
            .padding(.horizontal, 24)

            Spacer()

            // OTP dots
            VStack(spacing: 24) {
                // Hidden text field for keyboard input
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .onChange(of: code) {
                        code = String(code.filter(\.isNumber).prefix(codeLength))
                        if code.count == codeLength {
                            verify()
                        }
                    }

                // Dot indicators
                HStack(spacing: 16) {
                    ForEach(0..<codeLength, id: \.self) { index in
                        Circle()
                            .fill(index < code.count
                                ? Color.nook.primary
                                : Color.nook.border)
                            .frame(width: index < code.count ? 18 : 14,
                                   height: index < code.count ? 18 : 14)
                            .animation(.easeOut(duration: 0.15), value: code.count)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(NookFont.bodySmall)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if isLoading {
                    ProgressView()
                        .tint(Color.nook.primary)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Resend code
            Group {
                if resendCooldown > 0 {
                    Text("Resend code in \(resendCooldown)s")
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.mutedForeground)
                } else {
                    Button {
                        resend()
                    } label: {
                        Text("Resend code")
                            .font(NookFont.bodySmall)
                            .foregroundStyle(Color.nook.mutedForeground)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.bottom, 16)
        }
        .onAppear {
            isFocused = true
            startCooldown()
        }
        .alert("Code resent", isPresented: $showResendConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We sent a new code to \(email).")
        }
    }

    private func verify() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await router.verifyOTP(email: email, token: code)
            } catch {
                errorMessage = error.localizedDescription
                code = ""
            }
            isLoading = false
        }
    }

    private func resend() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await router.resendOTP(email: email)
                showResendConfirmation = true
                startCooldown()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
}

// MARK: - Auth Buttons

private enum SocialProvider {
    case apple, google
}

private struct IntroAuthButtons: View {
    let router: AppRouter
    @Binding var showEmailFlow: Bool

    @State private var loadingProvider: SocialProvider?
    @State private var errorMessage: String?
    @State private var appleSignInDelegate: AppleSignInDelegate?
    @State private var appeared = false

    private var isLoading: Bool { loadingProvider != nil }

    var body: some View {
        VStack(spacing: 12) {
            // Continue with Google
            Button {
                handleGoogle()
            } label: {
                HStack(spacing: 12) {
                    if loadingProvider == .google {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 20, height: 20)
                    } else {
                        Image("google-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }

                    Text("Continue with Google")
                        .font(NookFont.label)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.nook.foreground)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)

            // Continue with Apple
            Button {
                startAppleSignIn()
            } label: {
                HStack(spacing: 12) {
                    if loadingProvider == .apple {
                        ProgressView()
                            .tint(Color.nook.foreground)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.nook.foreground)
                            .frame(width: 20, height: 20)
                    }

                    Text("Continue with Apple")
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.foreground)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.nook.background)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.05), value: appeared)

            // Continue with Email
            Button {
                showEmailFlow = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nook.mutedForeground)
                        .frame(width: 20, height: 20)

                    Text("Continue with Email")
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.1), value: appeared)

            if let errorMessage {
                Text(errorMessage)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .animation(.easeOut(duration: 0.3), value: appeared)
        .onAppear {
            appeared = true
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
