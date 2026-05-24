import GoogleSignIn
import SwiftUI

@main
struct NookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    supabase.handle(url)
                }
        }
    }
}
