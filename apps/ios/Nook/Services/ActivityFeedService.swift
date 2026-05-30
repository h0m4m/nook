import Foundation
import Supabase

final class ActivityFeedService: Sendable {
    func getFeed(userId: UUID, page: Int = 1) async throws -> [ActivityFeedEntry] {
        // TODO: Implement in Prompt 11
        return []
    }

    func postActivity(
        actionType: String,
        mediaItemId: UUID?,
        referenceId: UUID?,
        referenceType: String?
    ) async throws {
        // TODO: Implement in Prompt 11
    }
}
