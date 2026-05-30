import Foundation
import Supabase

final class NotificationService: Sendable {
    func getNotifications(page: Int = 1) async throws -> [NotificationModel] {
        // TODO: Implement in Prompt 11
        return []
    }

    func markAsRead(notificationId: UUID) async throws {
        // TODO: Implement in Prompt 11
    }

    func markAllAsRead() async throws {
        // TODO: Implement in Prompt 11
    }

    func getUnreadCount() async throws -> Int {
        // TODO: Implement in Prompt 11
        return 0
    }
}
