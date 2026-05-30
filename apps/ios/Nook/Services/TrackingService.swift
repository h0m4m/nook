import Foundation
import Supabase

final class TrackingService: Sendable {
    private let libraryCache = InMemoryCache<UUID, [TrackedMediaItem]>(ttl: 300)

    func getLibrary(userId: UUID) async throws -> [TrackedMediaItem] {
        if let cached = await libraryCache.get(userId) {
            return cached
        }

        let rows: [TrackedMediaRow] = try await supabase
            .from("tracked_media")
            .select("*, media_item:media_items(*)")
            .eq("user_id", value: userId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value

        let items = rows.map { TrackedMediaItem(from: $0) }
        await libraryCache.set(userId, value: items)
        return items
    }

    func track(
        userId: UUID,
        mediaItemId: UUID,
        status: String,
        progress: Int = 0,
        score: Double? = nil
    ) async throws {
        struct TrackUpsert: Encodable {
            let user_id: String
            let media_item_id: String
            let status: String
            let progress: Int
            let score: Double?
        }

        try await supabase
            .from("tracked_media")
            .upsert(TrackUpsert(
                user_id: userId.uuidString,
                media_item_id: mediaItemId.uuidString,
                status: status,
                progress: progress,
                score: score
            ))
            .execute()

        await libraryCache.invalidate(userId)
    }

    func updateTracking(
        trackingId: UUID,
        status: String? = nil,
        progress: Int? = nil,
        score: Double? = nil
    ) async throws {
        var updates: [String: AnyEncodable] = [:]
        if let status { updates["status"] = AnyEncodable(status) }
        if let progress { updates["progress"] = AnyEncodable(progress) }
        if let score { updates["score"] = AnyEncodable(score) }

        try await supabase
            .from("tracked_media")
            .update(updates)
            .eq("id", value: trackingId.uuidString)
            .execute()

        await libraryCache.invalidateAll()
    }

    func removeTracking(trackingId: UUID) async throws {
        try await supabase
            .from("tracked_media")
            .delete()
            .eq("id", value: trackingId.uuidString)
            .execute()

        await libraryCache.invalidateAll()
    }

    func getTrackingForMedia(userId: UUID, mediaItemId: UUID) async throws -> TrackedMediaRow? {
        let rows: [TrackedMediaRow] = try await supabase
            .from("tracked_media")
            .select("*, media_item:media_items(*)")
            .eq("user_id", value: userId.uuidString)
            .eq("media_item_id", value: mediaItemId.uuidString)
            .execute()
            .value

        return rows.first
    }
}

// MARK: - AnyEncodable helper

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
