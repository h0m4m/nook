import SwiftUI

struct IntroView: View {
    var router: AppRouter

    var body: some View {
        ZStack {
            Color.nook.background
                .ignoresSafeArea()

            // Top gradient overlay
            VStack {
                LinearGradient(
                    colors: [
                        Color.nook.primary.opacity(0.05),
                        Color.nook.primary.opacity(0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 256)

                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero illustration placeholder
                heroIllustration
                    .frame(maxHeight: 354)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Spacer()
                    .frame(height: 48)

                // Text content
                VStack(spacing: 16) {
                    Text("Collect your worlds.")
                        .font(NookFont.displayLarge)
                        .tracking(-0.9)
                        .foregroundStyle(Color.nook.foreground)
                        .multilineTextAlignment(.center)

                    Text("Your personal corner of the internet to track media, express your taste, and curate collections of things you love.")
                        .font(NookFont.bodyMedium)
                        .lineSpacing(4)
                        .foregroundStyle(Color.nook.mutedForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        router.currentScreen = .signUp
                    } label: {
                        HStack(spacing: 10) {
                            Text("Get Started")
                                .font(NookFont.labelLarge)

                            Image("arrow-right")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.nook.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.nook.primary)
                        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm))
                        .shadow(
                            color: Color.nook.primary.opacity(0.2),
                            radius: 15,
                            x: 0,
                            y: 10
                        )
                        .shadow(
                            color: Color.nook.primary.opacity(0.2),
                            radius: 6,
                            x: 0,
                            y: 4
                        )
                    }

                    Button {
                        router.currentScreen = .signIn
                    } label: {
                        Text("I already have an account")
                            .font(NookFont.label)
                            .foregroundStyle(Color.nook.foreground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Hero Illustration (placeholder)

    private var heroIllustration: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.nook.secondary)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.nook.mutedForeground.opacity(0.3))
            )
    }
}

#Preview {
    IntroView(router: AppRouter())
}
