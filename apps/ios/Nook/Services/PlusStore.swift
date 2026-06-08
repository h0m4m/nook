import Foundation
import Supabase
import SwiftUI

/// Resolves whether arbitrary users are Nook Plus members, for the PLUS badge
/// shown next to names across the app. Looks up `user_profiles.is_plus` in
/// coalesced batches and caches the result. The *current* user is resolved live
/// from the SDK (see `UserPlusBadge`) so their own badge is instant.
@MainActor
@Observable
final class PlusStore {
    static let shared = PlusStore()

    private var cache: [UUID: Bool] = [:]
    @ObservationIgnored private var pending: Set<UUID> = []
    @ObservationIgnored private var inflight: Set<UUID> = []
    @ObservationIgnored private var batchTask: Task<Void, Never>?

    private init() {}

    /// Cached Plus status for a user — `false` until a lookup resolves.
    func isPlus(_ userId: UUID) -> Bool { cache[userId] ?? false }

    /// Queue a user for a batched `is_plus` lookup, unless already known/in-flight.
    /// Many badges calling this in the same frame collapse into one query.
    func prime(_ userId: UUID?) {
        guard let userId,
              cache[userId] == nil,
              !inflight.contains(userId),
              !pending.contains(userId)
        else { return }
        pending.insert(userId)
        batchTask?.cancel()
        batchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    private func flush() async {
        let ids = pending
        pending.removeAll()
        guard !ids.isEmpty else { return }
        inflight.formUnion(ids)
        defer { inflight.subtract(ids) }

        struct Row: Decodable {
            let id: UUID
            let is_plus: Bool?
        }

        let rows: [Row] = (try? await supabase
            .from("user_profiles")
            .select("id, is_plus")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value) ?? []

        var next = cache
        for id in ids { next[id] = false } // default any unresolved id to false
        for row in rows { next[row.id] = row.is_plus ?? false }
        cache = next
    }
}

/// Small "PLUS" chip shown next to a user's name when they're a Nook Plus member.
/// The current user resolves instantly from the SDK; everyone else is looked up
/// (and cached) by id via `PlusStore`. Renders nothing for non-members.
struct UserPlusBadge: View {
    let userId: UUID?

    @State private var store = PlusStore.shared
    @State private var subscriptions = SubscriptionManager.shared

    var body: some View {
        Group {
            if isPlus { PlusBadge() }
        }
        .task(id: userId) {
            guard let userId, userId != subscriptions.currentUserID else { return }
            store.prime(userId)
        }
    }

    private var isPlus: Bool {
        guard let userId else { return false }
        if userId == subscriptions.currentUserID { return subscriptions.isPlus }
        return store.isPlus(userId)
    }
}
