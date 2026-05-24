import SwiftUI

struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        ZStack {
            Color.nook.background.ignoresSafeArea()

            if router.isLoading {
                ProgressView()
                    .tint(Color.nook.primary)
            } else if router.currentScreen == .home {
                ContentView()
                    .transition(.opacity)
            } else if router.currentScreen == .signIn || router.currentScreen == .signUp {
                AuthView(router: router)
                    .transition(.opacity)
            } else {
                IntroView(router: router)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: router.currentScreen)
        .task {
            await router.checkAuth()
        }
    }
}

#Preview {
    RootView()
}
