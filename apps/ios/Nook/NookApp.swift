import GoogleSignIn
import SwiftUI

/// App-wide feature toggles.
enum FeatureFlags {
    /// Content sharing is hidden until we have a real share destination (e.g. a
    /// web app / universal links). The share UI is kept in code, just not shown.
    static let shareEnabled = false
}

@main
struct NookApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
