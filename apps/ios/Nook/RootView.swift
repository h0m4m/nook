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
        .environment(SubscriptionManager.shared)
        .environment(AdManager.shared)
        .animation(.easeInOut(duration: 0.35), value: router.currentScreen)
        .task {
            router.startListening()
            SubscriptionManager.shared.startAuthSync()
        }
        .task(id: router.currentScreen) {
            // Load the blocked-users set once the user reaches the app proper, so
            // content lists can filter blocked people out immediately.
            if router.currentScreen == .home {
                await BlockStore.shared.refresh()
                // Spin up ads only for free users, and only after they've reached
                // real content (ATT prompt "after first value"). The short delay
                // lets the RevenueCat entitlement resolve so Plus users are never
                // prompted for tracking nor shown ads.
                #if DEBUG
                print("🟡 [NookAds] home reached — isPlus=\(SubscriptionManager.shared.isPlus)")
                #endif
                if !SubscriptionManager.shared.isPlus {
                    try? await Task.sleep(for: .seconds(2))
                    #if DEBUG
                    print("🟡 [NookAds] after 2s — isPlus=\(SubscriptionManager.shared.isPlus) → starting ads")
                    #endif
                    if !SubscriptionManager.shared.isPlus {
                        AdManager.shared.startIfNeeded()
                    }
                }
            }
        }
    }
}

#Preview {
    RootView()
}
