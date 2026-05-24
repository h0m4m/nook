import SwiftUI

private enum AuthTab: Int, CaseIterable {
    case signIn = 0
    case joinNook = 1

    var title: String {
        switch self {
        case .signIn: "Sign In"
        case .joinNook: "Join Nook"
        }
    }
}

struct AuthView: View {
    var router: AppRouter

    @State private var activeTab: AuthTab = .signIn

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    AuthHeader()
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    AuthTitle(activeTab: activeTab)
                        .padding(.top, 48)
                        .padding(.horizontal, 24)

                    AuthTabSwitcher(activeTab: $activeTab)
                        .padding(.top, 32)
                        .padding(.horizontal, 24)

                    AuthFormFields(activeTab: activeTab, router: router)
                        .padding(.top, 32)
                        .padding(.horizontal, 24)

                    AuthSocialSection()
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.nook.background.ignoresSafeArea())
    }
}

// MARK: - Header (static, never re-renders)

private struct AuthHeader: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.nook.primary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "cube.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    )

                Text("nook")
                    .font(.custom("PlusJakartaSans-Bold", size: 24))
                    .tracking(-0.6)
                    .foregroundStyle(Color.nook.foreground)
            }

            Spacer()

            Button {
                // Help action
            } label: {
                Text("Help")
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.mutedForeground)
            }
        }
    }
}

// MARK: - Title (only re-renders on tab change)

private struct AuthTitle: View {
    let activeTab: AuthTab

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activeTab == .signIn ? "Welcome back" : "Let's get started")
                .font(.custom("PlusJakartaSans-Bold", size: 30))
                .lineSpacing(6)
                .foregroundStyle(Color.nook.foreground)

            Text(activeTab == .signIn
                ? "Sign in to continue your journey in the Nook."
                : "Your personal space awaits.")
                .font(NookFont.bodyMedium)
                .lineSpacing(4)
                .foregroundStyle(Color.nook.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tab Switcher

private struct AuthTabSwitcher: View {
    @Binding var activeTab: AuthTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.nook.segmentBackground)
                .frame(height: 48)

            HStack(spacing: 0) {
                ForEach(AuthTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(NookFont.labelSmall)
                            .foregroundStyle(
                                activeTab == tab
                                    ? Color.nook.foreground
                                    : Color.nook.mutedForeground
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .contentShape(Rectangle())
                            .background(
                                Group {
                                    if activeTab == tab {
                                        RoundedRectangle(cornerRadius: 11)
                                            .fill(Color.white)
                                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Form Fields (isolated — keystrokes stay here)

private struct AuthFormFields: View {
    let activeTab: AuthTab
    let router: AppRouter

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        let hasEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let hasPassword = password.count >= 6
        if activeTab == .signIn {
            return hasEmail && hasPassword
        }
        return hasEmail && hasPassword && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 0) {
            // Email
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

            Spacer().frame(height: 16)

            // Password
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Password")
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.mutedForeground)
                        .padding(.leading, 8)

                    Spacer()

                    if activeTab == .signIn {
                        Button {
                            // Forgot password action
                        } label: {
                            Text("Forgot password?")
                                .font(NookFont.captionSemiBold)
                                .foregroundStyle(Color.nook.primary.opacity(0.7))
                        }
                    }
                }

                NookTextField(
                    placeholder: "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}",
                    text: $password,
                    isSecure: true,
                    icon: "lock"
                )
                .textContentType(activeTab == .signIn ? .password : .newPassword)
            }

            // Confirm password (sign up only)
            if activeTab == .joinNook {
                Spacer().frame(height: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm Password")
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.mutedForeground)
                        .padding(.leading, 8)

                    NookTextField(
                        placeholder: "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}",
                        text: $confirmPassword,
                        isSecure: true,
                        icon: "lock"
                    )
                    .textContentType(.newPassword)
                }
            }

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            Spacer().frame(height: 32)

            // Submit button
            Button {
                submit()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(Color.white)
                    } else {
                        Text(activeTab == .signIn ? "Continue" : "Create Account")
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
        .onChange(of: activeTab) {
            email = ""
            password = ""
            confirmPassword = ""
            errorMessage = nil
        }
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, password.count >= 6 else {
            errorMessage = "Please enter a valid email and password (6+ characters)."
            return
        }
        if activeTab == .joinNook && password != confirmPassword {
            errorMessage = "Passwords don't match."
            return
        }

        isLoading = true
        errorMessage = nil
        Task {
            do {
                if activeTab == .signIn {
                    try await router.signIn(email: trimmedEmail, password: password)
                } else {
                    try await router.signUp(email: trimmedEmail, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Social Section (static, never re-renders)

private struct AuthSocialSection: View {
    var body: some View {
        VStack(spacing: 32) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.nook.border)
                    .frame(height: 1)

                Text("OR CONTINUE WITH")
                    .font(NookFont.captionBold)
                    .tracking(1.2)
                    .foregroundStyle(Color.nook.mutedForeground)
                    .fixedSize()
                    .padding(.horizontal, 16)

                Rectangle()
                    .fill(Color.nook.border)
                    .frame(height: 1)
            }

            HStack(spacing: 16) {
                SocialButton(label: "Apple") {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.nook.foreground)
                } action: {
                    // Apple sign-in
                }

                SocialButton(label: "Google") {
                    Image("google-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } action: {
                    // Google sign-in
                }
            }
        }
    }
}

private struct SocialButton<Icon: View>: View {
    let label: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon()
                    .frame(width: 20, height: 20)

                Text(label)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.foreground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.nook.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Sign In") {
    AuthView(router: AppRouter())
}
