import Foundation

/// Where a tapped push notification should take the user. Mirrors the in-app
/// NotificationsView tap behaviour: club refs open the club, everything else opens
/// the actor's profile.
enum PushRoute: Equatable, Sendable {
    case club(id: UUID)
    case profile(id: UUID, name: String, avatarURL: URL?)
    case notifications
}

/// Bridges a notification tap (handled in AppDelegate, outside SwiftUI) to the
/// NavigationStack in MainTabView. AppDelegate parses the payload and sets
/// `pendingRoute`; MainTabView observes it, navigates, then clears it.
@MainActor
@Observable
final class PushRouter {
    static let shared = PushRouter()
    private init() {}

    var pendingRoute: PushRoute?

    func setPendingRoute(_ route: PushRoute) {
        pendingRoute = route
    }

    /// Parse the APNs `userInfo` custom keys set by the `send-push` edge function.
    /// `nonisolated` so it can run in the AppDelegate delegate callback before hopping
    /// to the main actor — the returned `PushRoute` is Sendable, the dictionary is not.
    nonisolated static func parse(_ userInfo: [AnyHashable: Any]) -> PushRoute? {
        let refType = userInfo["ref_type"] as? String
        let refId = (userInfo["ref_id"] as? String).flatMap(UUID.init(uuidString:))
        let actorId = (userInfo["actor_id"] as? String).flatMap(UUID.init(uuidString:))
        let actorName = userInfo["actor_name"] as? String ?? "Someone"
        let actorAvatar = (userInfo["actor_avatar"] as? String).flatMap { URL(string: $0) }

        if refType == "club", let clubId = refId {
            return .club(id: clubId)
        } else if let actorId {
            return .profile(id: actorId, name: actorName, avatarURL: actorAvatar)
        }
        return .notifications
    }
}
