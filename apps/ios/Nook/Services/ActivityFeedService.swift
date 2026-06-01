import Foundation
import Supabase

final class ActivityFeedService: Sendable {
    func getFeed(page: Int = 1) async throws -> [ActivityFeedEntry] {
        let userId = try await supabase.auth.session.user.id
        let limit = 20
        let offset = (page - 1) * limit

        // Get IDs of users the current user follows
        struct FollowRow: Decodable {
            let following_id: UUID
        }

        let follows: [FollowRow] = try await supabase
            .from("user_follows")
            .select("following_id")
            .eq("follower_id", value: userId.uuidString)
            .execute()
            .value

        let followedIds = follows.map { $0.following_id.uuidString }

        guard !followedIds.isEmpty else { return [] }

        let rows: [ActivityFeedRow] = try await supabase
            .from("activity_feed")
            .select("*, user_profile:user_profiles!activity_feed_user_id_user_profiles_fkey(id, full_name, username, avatar_url), media_item:media_items!media_item_id(id, source, source_id, media_type, title, image_url, year)")
            .in("user_id", values: followedIds)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return rows.map { ActivityFeedEntry(from: $0) }
    }

    func postActivity(
        actionType: String,
        mediaItemId: UUID?,
        referenceId: UUID?,
        referenceType: String?
    ) async throws {
        let userId = try await supabase.auth.session.user.id

        struct ActivityInsert: Encodable {
            let user_id: String
            let action_type: String
            let media_item_id: String?
            let reference_id: String?
            let reference_type: String?
        }

        try await supabase
            .from("activity_feed")
            .insert(ActivityInsert(
                user_id: userId.uuidString,
                action_type: actionType,
                media_item_id: mediaItemId?.uuidString,
                reference_id: referenceId?.uuidString,
                reference_type: referenceType
            ))
            .execute()
    }
}
