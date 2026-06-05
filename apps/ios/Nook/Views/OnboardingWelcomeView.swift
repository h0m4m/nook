import SwiftUI

/// First stop after auth for a brand-new user: a warm, on-brand welcome that
/// sells what Nook is before we ask them to set anything up. Purely
/// presentational — the single CTA hands off to the profile-setup step.
struct OnboardingWelcomeView: View {
    var router: AppRouter

    @State private var appeared = false

    private let features: [WelcomeFeature] = [
        WelcomeFeature(
            icon: "bookmark-simple-fill",
            tint: Color.nook.profileStatTracked,
            tintBackground: Color.nook.profileStatTrackedBg,
            title: "Track everything",
            subtitle: "Movies, TV, anime, manga, books & games — one library."
        ),
        WelcomeFeature(
            icon: "star-fill",
            tint: Color.nook.profileStatReviews,
            tintBackground: Color.nook.profileStatReviewsBg,
            title: "Rate & review",
            subtitle: "Share your takes and remember what you loved."
        ),
        WelcomeFeature(
            icon: "users-three-fill",
            tint: Color.nook.profileStatCommunities,
            tintBackground: Color.nook.profileStatCommunitiesBg,
            title: "Find your people",
            subtitle: "Join clubs and follow friends with the same taste."
        ),
        WelcomeFeature(
            icon: "chart-line",
            tint: Color.nook.profileStatNooks,
            tintBackground: Color.nook.profileStatNooksBg,
            title: "See your stats",
            subtitle: "Watch your taste come to life over time."
        ),
    ]

    var body: some View {
        ZStack {
            Color.nook.onboardingBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Wordmark
                HStack(spacing: 8) {
                    Image("sparkle")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.accent)

                    Text("NOOK")
                        .font(NookFont.outfitLabelBold)
                        .tracking(3)
                        .foregroundStyle(Color.nook.onboardingPrimary)
                }
                .padding(.top, 44)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                // Headline
                Text("Welcome to your\ncozy media corner.")
                    .font(NookFont.outfitDisplay)
                    .lineSpacing(0)
                    .foregroundStyle(Color.nook.onboardingHeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.06), value: appeared)

                Text("Everything you watch, read, and play — tracked, rated, and shared in one place.")
                    .font(NookFont.bodyMedium)
                    .lineSpacing(4)
                    .foregroundStyle(Color.nook.onboardingSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.12), value: appeared)

                // Bias the feature list toward the top: cap the gap above it so
                // the remaining slack pools below, nudging the items up.
                Spacer(minLength: 24).frame(maxHeight: 64)

                // Feature list
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        WelcomeFeatureRow(feature: feature, appeared: appeared, index: index)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 28)

                // CTA
                Button {
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                    router.continueFromWelcome()
                } label: {
                    Text("Let's get started")
                        .font(.custom("PlusJakartaSans-Bold", size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(Color.nook.onboardingPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 18.89, style: .continuous))
                        .shadow(color: Color.nook.onboardingPrimary.opacity(0.2), radius: 12.5, x: 0, y: 10)
                        .shadow(color: Color.nook.onboardingPrimary.opacity(0.2), radius: 5, x: 0, y: 4)
                }
                .buttonStyle(WelcomeScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
            }
        }
        .animation(.easeOut(duration: 0.5), value: appeared)
        .onAppear { appeared = true }
    }
}

// MARK: - Feature Model + Row

private struct WelcomeFeature: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let tintBackground: Color
    let title: String
    let subtitle: String
}

private struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature
    let appeared: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(feature.tintBackground)
                    .frame(width: 48, height: 48)

                Image(feature.icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(feature.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(NookFont.outfitLabel)
                    .foregroundStyle(Color.nook.onboardingHeading)

                Text(feature.subtitle)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.onboardingSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.easeOut(duration: 0.5).delay(0.18 + Double(index) * 0.08), value: appeared)
    }
}

// MARK: - Button Style

private struct WelcomeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingWelcomeView(router: AppRouter())
}
