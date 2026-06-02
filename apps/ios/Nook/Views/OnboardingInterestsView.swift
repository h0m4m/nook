import SwiftUI

// MARK: - Interest Model

enum MediaInterest: String, CaseIterable, Identifiable {
    case movies = "movies"
    case tvShows = "tv_shows"
    case anime = "anime"
    case manga = "manga"
    case books = "books"
    case games = "games"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .movies: "Movies"
        case .tvShows: "TV Shows"
        case .anime: "Anime"
        case .manga: "Manga"
        case .books: "Books"
        case .games: "Games"
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .movies: Color(hex: 0xE8E2D9, alpha: 0.4)
        case .tvShows: Color(hex: 0xD4DFE8, alpha: 0.3)
        case .anime: Color(hex: 0xEAD6DF, alpha: 0.3)
        case .manga: Color(hex: 0xD3E1D2, alpha: 0.3)
        case .books: Color(hex: 0xE8E2D9, alpha: 0.4)
        case .games: Color(hex: 0xE4C7BA, alpha: 0.3)
        }
    }

    var iconColor: Color {
        switch self {
        case .movies: Color(hex: 0x968A79)
        case .tvShows: Color(hex: 0x7896B2)
        case .anime: Color(hex: 0xB68B9F)
        case .manga: Color(hex: 0x7C9E7B)
        case .books: Color(hex: 0x968A79)
        case .games: Color(hex: 0xB58572)
        }
    }

    var iconName: String {
        switch self {
        case .movies: "reel"
        case .tvShows: "videocamera-record"
        case .anime: "star-fall"
        case .manga: "notes"
        case .books: "book"
        case .games: "gamepad"
        }
    }

    var apiMediaType: String {
        switch self {
        case .movies: "movie"
        case .tvShows: "tv"
        case .anime: "anime"
        case .manga: "manga"
        case .books: "book"
        case .games: "game"
        }
    }
}

// MARK: - Main View

struct OnboardingInterestsView: View {
    var router: AppRouter

    @State private var selectedInterests: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            Color.nook.onboardingBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Heading
                Text("Choose your worlds.")
                    .font(NookFont.outfitDisplay)
                    .lineSpacing(9)
                    .foregroundStyle(Color.nook.onboardingHeading)
                    .padding(.top, 44)
                    .padding(.horizontal, 24)
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)

                // Subtitle
                Text("Select the media you want to track and explore. You can change this later.")
                    .font(NookFont.bodyMedium)
                    .lineSpacing(4)
                    .foregroundStyle(Color.nook.onboardingSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.08), value: appeared)

                Spacer()
                    .frame(minHeight: 24, maxHeight: .infinity)

                // Interest grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(MediaInterest.allCases.enumerated()), id: \.element.id) { index, interest in
                        InterestCard(
                            interest: interest,
                            isSelected: selectedInterests.contains(interest.rawValue),
                            appeared: appeared,
                            index: index
                        ) {
                            toggleInterest(interest)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(minHeight: 24, maxHeight: .infinity)

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(NookFont.bodySmall)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Continue button
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.45), value: appeared)
            }
        }
        .animation(.easeOut(duration: 0.5), value: appeared)
        .onAppear {
            appeared = true
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.nook.onboardingPrimary)
                .frame(width: 48, height: 6)

            RoundedRectangle(cornerRadius: 100)
                .fill(Color.nook.onboardingPrimary)
                .frame(width: 48, height: 6)

            RoundedRectangle(cornerRadius: 100)
                .fill(Color.nook.onboardingPrimary.opacity(0.2))
                .frame(width: 48, height: 6)

            RoundedRectangle(cornerRadius: 100)
                .fill(Color.nook.onboardingPrimary.opacity(0.2))
                .frame(width: 48, height: 6)

            Spacer()
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            save()
        } label: {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.custom("PlusJakartaSans-Bold", size: 18))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(
                selectedInterests.isEmpty
                    ? Color.nook.onboardingPrimary.opacity(0.4)
                    : Color.nook.onboardingPrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: 18.89, style: .continuous))
            .shadow(
                color: Color.nook.onboardingPrimary.opacity(0.2),
                radius: 12.5,
                x: 0,
                y: 10
            )
            .shadow(
                color: Color.nook.onboardingPrimary.opacity(0.2),
                radius: 5,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(selectedInterests.isEmpty || isSaving)
        .animation(.easeOut(duration: 0.2), value: selectedInterests.isEmpty)
    }

    // MARK: - Actions

    private func toggleInterest(_ interest: MediaInterest) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if selectedInterests.contains(interest.rawValue) {
                selectedInterests.remove(interest.rawValue)
            } else {
                selectedInterests.insert(interest.rawValue)
                generator.impactOccurred()
            }
        }
    }

    private func save() {
        guard !selectedInterests.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        Task {
            do {
                try await router.saveInterests(selectedInterests)
                generator.notificationOccurred(.success)
            } catch {
                withAnimation(.easeOut(duration: 0.2)) {
                    errorMessage = error.localizedDescription
                }
                generator.notificationOccurred(.error)
            }
            isSaving = false
        }
    }
}

// MARK: - Interest Card

private struct InterestCard: View {
    let interest: MediaInterest
    let isSelected: Bool
    let appeared: Bool
    let index: Int
    let onTap: () -> Void

    // Stagger: 60ms per card, starting at 150ms base delay
    private var staggerDelay: Double {
        0.15 + Double(index) * 0.06
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    // Icon container
                    ZStack {
                        RoundedRectangle(cornerRadius: 17.78, style: .continuous)
                            .fill(interest.iconBackgroundColor)
                            .frame(width: 56, height: 56)

                        Image(interest.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .foregroundStyle(interest.iconColor)
                    }

                    // Label
                    Text(interest.label)
                        .font(NookFont.outfitLabel)
                        .foregroundStyle(Color.nook.onboardingHeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Checkmark badge
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.nook.onboardingPrimary)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 18)
                    .padding(.trailing, 18)
                    .transition(
                        .scale(scale: 0.5)
                        .combined(with: .opacity)
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 144)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.nook.onboardingPrimary
                            : Color(hex: 0xE8E3E1, alpha: 0.5),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(CardButtonStyle())
        .offset(y: appeared ? 0 : 16)
        .opacity(appeared ? 1 : 0)
        .animation(
            .easeOut(duration: 0.45).delay(staggerDelay),
            value: appeared
        )
    }
}

// MARK: - Button Styles

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    OnboardingInterestsView(router: AppRouter())
}
