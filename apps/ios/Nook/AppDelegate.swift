import UIKit
import UserNotifications

/// Hosts the APNs + UNUserNotificationCenter callbacks that SwiftUI's App lifecycle
/// doesn't surface. Wired in via `@UIApplicationDelegateAdaptor` in NookApp.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Configure RevenueCat early, before any logIn / offerings calls.
        MainActor.assumeIsolated {
            SubscriptionManager.shared.configure()
        }
        return true
    }

    // APNs handed us a device token — sync it to Supabase.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushService.shared.handleNewToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    // Show a banner (and update badge/sound) even while the app is foregrounded.
    // `nonisolated`: the UNUserNotificationCenterDelegate requirement passes
    // non-Sendable arguments, so it can't cross into the main actor.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    // The user tapped a notification — route into the app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let route = PushRouter.parse(response.notification.request.content.userInfo) {
            await PushRouter.shared.setPendingRoute(route)
        }
    }
}
