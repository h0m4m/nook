import Foundation
import Supabase
import UIKit
import UserNotifications

/// Owns the APNs lifecycle on the client: permission, registration, syncing the
/// device token to Supabase (`device_tokens`), sign-out cleanup, and the app badge.
@MainActor
final class PushService {
    static let shared = PushService()
    private init() {}

    private let tokenDefaultsKey = "apnsDeviceTokenHex"

    /// Development builds register a sandbox APNs token, release builds a production
    /// one. `send-push` routes to the matching APNs host per stored environment.
    private var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    // MARK: - Permission & registration

    /// Ask for permission (prompts only the first time) and register with APNs when
    /// granted. Returns whether notifications are authorized.
    @discardableResult
    func requestAuthorizationAndRegister() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    /// If already authorized, (re)register to refresh the token — used on launch/sign-in
    /// without prompting.
    func registerIfAuthorized() async {
        let status = await authorizationStatus()
        if status == .authorized || status == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Token sync

    /// Called from AppDelegate when APNs delivers a token.
    func handleNewToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: tokenDefaultsKey)
        Task { await uploadToken(hex) }
    }

    /// Re-upload the cached token (e.g. right after sign-in, when a token may have
    /// arrived before there was a session to attach it to).
    func uploadCachedTokenIfAvailable() async {
        if let hex = UserDefaults.standard.string(forKey: tokenDefaultsKey) {
            await uploadToken(hex)
        }
    }

    private func uploadToken(_ hex: String) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        struct TokenUpsert: Encodable {
            let user_id: String
            let token: String
            let platform: String
            let environment: String
            let app_version: String?
            let locale: String
            let updated_at: String
        }

        let payload = TokenUpsert(
            user_id: userId.uuidString,
            token: hex,
            platform: "ios",
            environment: environment,
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            locale: Locale.current.identifier,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        // Unique on `token`: re-using a device under a new account moves the row.
        _ = try? await supabase
            .from("device_tokens")
            .upsert(payload, onConflict: "token")
            .execute()
    }

    /// Delete this device's token row. Call BEFORE `supabase.auth.signOut()` so RLS
    /// (auth.uid() = user_id) still permits the delete.
    func clearCurrentDeviceToken() async {
        guard let hex = UserDefaults.standard.string(forKey: tokenDefaultsKey) else { return }
        _ = try? await supabase
            .from("device_tokens")
            .delete()
            .eq("token", value: hex)
            .execute()
    }

    // MARK: - Badge

    func setBadge(_ count: Int) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(max(0, count)) }
    }
}
