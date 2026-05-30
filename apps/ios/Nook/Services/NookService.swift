import Foundation
import Supabase

final class NookService: Sendable {
    func createNook(
        name: String,
        description: String?,
        coverData: Data?,
        privacy: String,
        layout: String,
        items: [(mediaItemId: UUID, note: String?, sortOrder: Int)]
    ) async throws -> NookRow {
        // TODO: Implement in Prompt 9
        fatalError("Not implemented")
    }

    func getNook(nookId: UUID) async throws -> NookDetail {
        // TODO: Implement in Prompt 9
        fatalError("Not implemented")
    }

    func getUserNooks(userId: UUID) async throws -> [NookRow] {
        // TODO: Implement in Prompt 9
        return []
    }

    func updateNook(nookId: UUID, name: String?, description: String?, privacy: String?, layout: String?) async throws {
        // TODO: Implement in Prompt 9
    }

    func deleteNook(nookId: UUID) async throws {
        // TODO: Implement in Prompt 9
    }

    func getPopularNooks(limit: Int = 10) async throws -> [NookRow] {
        // TODO: Implement in Prompt 9
        return []
    }
}
