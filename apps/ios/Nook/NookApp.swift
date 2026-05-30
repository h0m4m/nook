import GoogleSignIn
import SwiftUI

@main
struct NookApp: App {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50_000_000,
            diskCapacity: 100_000_000,
            diskPath: "nook_url_cache"
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    supabase.handle(url)
                }
        }
    }
}
