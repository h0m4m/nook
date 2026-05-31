import SwiftUI

/// Shared observable service that tracks which mediaIds have been tracked in the current session.
/// Injected via @Environment so SearchView can reactively update its rows after returning from detail.
@Observable
final class TrackingStateService: @unchecked Sendable {
    var trackedMediaIds: Set<String> = []

    @MainActor
    func markTracked(_ mediaId: String) {
        trackedMediaIds.insert(mediaId)
    }
}

// MARK: - Environment Key

private struct TrackingStateServiceKey: EnvironmentKey {
    static let defaultValue = TrackingStateService()
}

extension EnvironmentValues {
    var trackingState: TrackingStateService {
        get { self[TrackingStateServiceKey.self] }
        set { self[TrackingStateServiceKey.self] = newValue }
    }
}
