import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()
    @State private var trackingState = TrackingStateService()

    var body: some View {
        ZStack {
            Color.nook.background.ignoresSafeArea()

            if router.isLoading {
                ProgressView()
                    .tint(Color.nook.primary)
            } else {
                switch router.currentScreen {
                case .home:
                    MainTabView(router: router)
                        .transition(.opacity)
                case .onboarding:
                    OnboardingInterestsView(router: router)
                        .transition(.opacity)
                case .profileSetup:
                    OnboardingProfileView(router: router)
                        .transition(.opacity)
                case .welcome:
                    OnboardingWelcomeView(router: router)
                        .transition(.opacity)
                case .intro:
                    IntroView(router: router)
                        .transition(.opacity)
                }
            }
        }
        .environment(\.trackingState, trackingState)
        .animation(.easeInOut(duration: 0.35), value: router.currentScreen)
        .task {
            router.startListening()
        }
        .task(id: router.currentScreen) {
            // Load the blocked-users set once the user reaches the app proper, so
            // content lists can filter blocked people out immediately.
            if router.currentScreen == .home {
                await BlockStore.shared.refresh()
            }
        }
    }
}

#Preview {
    RootView()
}
