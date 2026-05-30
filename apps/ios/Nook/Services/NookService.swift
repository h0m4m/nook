import Foundation
import Supabase

final class NookService: Sendable {
    func createNook(
        name: String,
        description: String?,
        coverData: Data?,
        privacy: String,
        layout: String
    ) async throws -> UUID {
        let userId = try await supabase.auth.session.user.id

        // Upload cover if provided
        var coverUrl: String?
        if let coverData {
            let storageService = StorageService()
            let url = try await storageService.uploadImage(
                bucket: "nook-covers",
                userId: userId,
                fileName: "\(UUID().uuidString).jpg",
                data: coverData
            )
            coverUrl = url.absoluteString
        }

        struct NookInsert: Encodable {
            let user_id: String
            let name: String
            let description: String?
            let cover_url: String?
            let privacy: String
            let layout: String
        }

        struct NookResult: Decodable {
            let id: UUID
        }

        let result: NookResult = try await supabase
            .from("nooks")
            .insert(NookInsert(
                user_id: userId.uuidString,
                name: name,
                description: description,
                cover_url: coverUrl,
                privacy: privacy,
                layout: layout
            ))
            .select("id")
            .single()
            .execute()
            .value

        // Insert activity feed entry
        struct ActivityInsert: Encodable {
            let user_id: String
            let action_type: String
            let reference_id: String
            let reference_type: String
        }

        try? await supabase
            .from("activity_feed")
            .insert(ActivityInsert(
                user_id: userId.uuidString,
                action_type: "created_nook",
                reference_id: result.id.uuidString,
                reference_type: "nook"
            ))
            .execute()

        return result.id
    }

    func addItems(
        nookId: UUID,
        items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]
    ) async throws {
        struct ItemInsert: Encodable {
            let nook_id: String
            let media_item_id: String
            let note: String?
            let sort_order: Int
        }

        let rows = items.map {
            ItemInsert(
                nook_id: nookId.uuidString,
                media_item_id: $0.mediaItemId.uuidString,
                note: $0.note,
                sort_order: $0.sortOrder
            )
        }

        try await supabase
            .from("nook_items")
            .insert(rows)
            .execute()
    }

    func getNook(nookId: UUID) async throws -> NookDetail {
        let row: NookRow = try await supabase
            .from("nooks")
            .select("*")
            .eq("id", value: nookId.uuidString)
            .single()
            .execute()
            .value

        let itemRows: [NookItemRow] = try await supabase
            .from("nook_items")
            .select("*, media_item:media_items(*)")
            .eq("nook_id", value: nookId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value

        // Get owner profile
        struct OwnerRow: Decodable {
            let full_name: String?
            let avatar_url: String?
        }

        let owner: OwnerRow? = try? await supabase
            .from("user_profiles")
            .select("full_name, avatar_url")
            .eq("id", value: row.userId.uuidString)
            .single()
            .execute()
            .value

        return NookDetail(
            nook: NookCollection(from: row),
            items: itemRows.map { NookMediaEntry(from: $0) },
            ownerName: owner?.full_name,
            ownerAvatarURL: owner?.avatar_url.flatMap { URL(string: $0) }
        )
    }

    func getUserNooks(userId: UUID) async throws -> [NookRow] {
        try await supabase
            .from("nooks")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateNook(nookId: UUID, name: String?, description: String?, privacy: String?, layout: String?) async throws {
        var updates: [String: AnyEncodable] = [:]
        if let name { updates["name"] = AnyEncodable(name) }
        if let description { updates["description"] = AnyEncodable(description) }
        if let privacy { updates["privacy"] = AnyEncodable(privacy) }
        if let layout { updates["layout"] = AnyEncodable(layout) }

        guard !updates.isEmpty else { return }

        try await supabase
            .from("nooks")
            .update(updates)
            .eq("id", value: nookId.uuidString)
            .execute()
    }

    func deleteNook(nookId: UUID) async throws {
        try await supabase
            .from("nooks")
            .delete()
            .eq("id", value: nookId.uuidString)
            .execute()
    }

    func getPopularNooks(limit: Int = 10) async throws -> [NookRow] {
        try await supabase
            .from("nooks")
            .select("*")
            .eq("privacy", value: "public")
            .order("created_at", ascending: false)
            .range(from: 0, to: limit - 1)
            .execute()
            .value
    }
}
