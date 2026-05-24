import SwiftUI

struct EmailConfirmationView: View {
    let router: AppRouter
    let email: String

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button {
                            router.currentScreen = .signUp
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.nook.foreground)
                        }

                        Spacer()
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                    // Icon
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.nook.segmentBackground)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "envelope.badge")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.nook.primary)
                        )
                        .padding(.top, 48)

                    // Title
                    VStack(spacing: 12) {
                        Text("Check your email")
                            .font(.custom("PlusJakartaSans-Bold", size: 28))
                            .foregroundStyle(Color.nook.foreground)

                        Text("We sent a 6-digit code to")
                            .font(NookFont.bodyMedium)
                            .foregroundStyle(Color.nook.mutedForeground)

                        Text(email)
                            .font(NookFont.labelSmall)
                            .foregroundStyle(Color.nook.foreground)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                    // OTP input
                    OTPFields(router: router, email: email)
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.nook.background.ignoresSafeArea())
    }
}

// MARK: - OTP Fields (isolated state)

private struct OTPFields: View {
    let router: AppRouter
    let email: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showResendConfirmation = false
    @State private var resendCooldown = 0

    @FocusState private var isFocused: Bool

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 0) {
            // Hidden text field for keyboard input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: code) {
                    // Only allow digits, cap at 6
                    code = String(code.filter(\.isNumber).prefix(codeLength))
                    if code.count == codeLength {
                        verify()
                    }
                }

            // Code boxes
            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    let char = index < code.count
                        ? String(code[code.index(code.startIndex, offsetBy: index)])
                        : ""

                    Text(char)
                        .font(.custom("PlusJakartaSans-Bold", size: 24))
                        .foregroundStyle(Color.nook.foreground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    index == code.count && isFocused
                                        ? Color.nook.primary
                                        : Color.nook.border,
                                    lineWidth: index == code.count && isFocused ? 2 : 1
                                )
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }

            // Loading indicator
            if isLoading {
                ProgressView()
                    .tint(Color.nook.primary)
                    .padding(.top, 24)
            }

            // Resend
            HStack(spacing: 4) {
                Text("Didn't get the code?")
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.mutedForeground)

                if resendCooldown > 0 {
                    Text("Resend in \(resendCooldown)s")
                        .font(NookFont.captionSemiBold)
                        .foregroundStyle(Color.nook.mutedForeground)
                } else {
                    Button {
                        resend()
                    } label: {
                        Text("Resend")
                            .font(NookFont.captionSemiBold)
                            .foregroundStyle(Color.nook.primary)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.top, 32)
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
                try await router.resendConfirmation(email: email)
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

#Preview {
    EmailConfirmationView(router: AppRouter(), email: "test@example.com")
}
