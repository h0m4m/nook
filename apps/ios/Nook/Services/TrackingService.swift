import Foundation
import Supabase

extension Notification.Name {
    /// Posted whenever tracked media is added, updated, or removed so list
    /// surfaces (Library, Home, Profile) can refresh.
    static let trackedMediaDidChange = Notification.Name("trackedMediaDidChange")
}

final class TrackingService: Sendable {
    /// Shared across all `TrackingService` instances so a write from one screen
    /// (detail, search) invalidates the cache the Library reads from.
    private static let libraryCache = InMemoryCache<UUID, [TrackedMediaItem]>(ttl: 300)

    private func notifyChanged() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .trackedMediaDidChange, object: nil)
        }
    }

    func getLibrary(userId: UUID) async throws -> [TrackedMediaItem] {
        if let cached = await Self.libraryCache.get(userId) {
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
        await Self.libraryCache.set(userId, value: items)
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
            .upsert(
                TrackUpsert(
                    user_id: userId.uuidString,
                    media_item_id: mediaItemId.uuidString,
                    status: status,
                    progress: progress,
                    score: score
                ),
                onConflict: "user_id,media_item_id"
            )
            .execute()

        await Self.libraryCache.invalidate(userId)
        await notifyChanged()
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

        await Self.libraryCache.invalidateAll()
        await notifyChanged()
    }

    func removeTracking(trackingId: UUID) async throws {
        try await supabase
            .from("tracked_media")
            .delete()
            .eq("id", value: trackingId.uuidString)
            .execute()

        await Self.libraryCache.invalidateAll()
        await notifyChanged()
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
