import GoogleSignIn
import SwiftUI

@main
struct NookApp: App {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system

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
