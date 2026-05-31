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
    }
}

#Preview {
    RootView()
}
