import Foundation
import Supabase

final class NotificationService: Sendable {
    func getNotifications(page: Int = 1) async throws -> [NotificationModel] {
        let userId = try await supabase.auth.session.user.id
        let limit = 20
        let offset = (page - 1) * limit

        let rows: [NotificationDBRow] = try await supabase
            .from("notifications")
            .select("*, actor:user_profiles!notifications_actor_id_user_profiles_fkey(id, full_name, username, avatar_url)")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.map { NotificationModel(from: $0) }
    }

    func markAsRead(notificationId: UUID) async throws {
        struct Update: Encodable {
            let is_read: Bool
        }

        try await supabase
            .from("notifications")
            .update(Update(is_read: true))
            .eq("id", value: notificationId.uuidString)
            .execute()
    }

    func markAllAsRead() async throws {
        let userId = try await supabase.auth.session.user.id

        struct Update: Encodable {
            let is_read: Bool
        }

        try await supabase
            .from("notifications")
            .update(Update(is_read: true))
            .eq("user_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()
    }

    func getUnreadCount() async throws -> Int {
        let userId = try await supabase.auth.session.user.id

        struct Row: Decodable {
            let id: UUID
        }

        let rows: [Row] = try await supabase
            .from("notifications")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()
            .value

        return rows.count
    }

    /// Live stream that emits whenever a new notification row is inserted for the
    /// current user (via Supabase Realtime — the `notifications` table is in the
    /// `supabase_realtime` publication). Emits `Void` per insert; callers typically
    /// re-read `getUnreadCount()` on each tick. The channel is torn down
    /// automatically when the consuming task is cancelled.
    func observeNewNotifications() async throws -> AsyncStream<Void> {
        let userId = try await supabase.auth.session.user.id

        let channel = supabase.channel("notifications:\(userId.uuidString)")
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: .eq("user_id", value: userId.uuidString)
        )
        try await channel.subscribe()

        return AsyncStream { continuation in
            let task = Task {
                for await _ in insertions {
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await supabase.removeChannel(channel) }
            }
        }
    }
}
