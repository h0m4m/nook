import Foundation
import SwiftUI
import Supabase

enum LibraryContentMode: CaseIterable, Identifiable {
    case media
    case nooks

    var id: String {
        switch self {
        case .media: "media"
        case .nooks: "nooks"
        }
    }

    var label: String {
        switch self {
        case .media: "Media"
        case .nooks: "Nooks"
        }
    }
}

@MainActor
@Observable
final class LibraryViewModel {
    var items: [TrackedMediaItem] = []
    var selectedFilter: LibraryFilter = .all
    var selectedSort: LibrarySortOption = .lastUpdated
    var searchText: String = ""
    var isLoading = false
    var error: AppError?

    var mode: LibraryContentMode = .media
    var nooks: [NookSummary] = []
    var isLoadingNooks = false
    var hasLoadedNooks = false

    private let trackingService = TrackingService()
    private let nookService = NookService()

    private var lastLoaded: Date?
    nonisolated(unsafe) private var changeObserver: NSObjectProtocol?

    init() {
        // The view model outlives individual tab views (it's owned by MainTabView),
        // so we observe tracked-media changes here rather than in the view. That way
        // a track/edit from another tab (e.g. Search) still refreshes the library
        // even though LibraryView isn't in the hierarchy at the time.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .trackedMediaDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reloadAfterExternalChange() }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    var filteredItems: [TrackedMediaItem] {
        var results = items

        switch selectedFilter {
        case .all: break
        case .inProgress:
            results = results.filter { $0.status == "in_progress" }
        case .planned:
            results = results.filter { $0.status == "planned" }
        case .onHold:
            results = results.filter { $0.status == "on_hold" }
        case .dropped:
            results = results.filter { $0.status == "dropped" }
        case .completed:
            results = results.filter { $0.status == "completed" }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch selectedSort {
        case .status:
            let order: [String] = ["in_progress", "planned", "on_hold", "completed", "dropped"]
            results.sort { (order.firstIndex(of: $0.status) ?? 99) < (order.firstIndex(of: $1.status) ?? 99) }
        case .alphabetical:
            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .score:
            results.sort { ($0.score ?? -1) > ($1.score ?? -1) }
        case .progress:
            results.sort { $0.progress > $1.progress }
        case .airStartDate:
            results.sort { ($0.year ?? "") > ($1.year ?? "") }
        case .lastUpdated:
            results.sort { $0.updatedAt > $1.updatedAt }
        }

        return results
    }

    var filteredNooks: [NookSummary] {
        guard !searchText.isEmpty else { return nooks }
        return nooks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Called when the Library tab appears. Shows existing items instantly and
    /// only refetches when there's nothing loaded yet or the data is stale —
    /// so returning to the tab no longer flashes a skeleton.
    func loadIfNeeded() async {
        if items.isEmpty {
            await loadLibrary()          // first load: skeleton is fine
        } else {
            await refreshSilently()      // have data: revalidate without a skeleton
        }
    }

    func loadLibrary() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        isLoading = true
        error = nil

        do {
            items = try await trackingService.getLibrary(userId: userId)
            lastLoaded = Date()
            ImagePrefetcher.prefetch(items.map(\.imageURL))
            isLoading = false
        } catch {
            // Only surface an error on a cold load. If we already have items,
            // a transient refresh failure should keep the current list on screen
            // rather than replacing it with a scary banner.
            if items.isEmpty {
                self.error = AppError(from: error)
            }
            isLoading = false
        }
    }

    /// Called when tracked media changes elsewhere (detail, search). Refetches
    /// without a skeleton when we already have a list, otherwise does a full load.
    func reloadAfterExternalChange() async {
        if items.isEmpty {
            await loadLibrary()
        } else {
            await refreshSilently()
        }
    }

    /// Background refresh that keeps the current list on screen (no loading flag).
    private func refreshSilently() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        if let fresh = try? await trackingService.getLibrary(userId: userId) {
            items = fresh
            lastLoaded = Date()
            ImagePrefetcher.prefetch(items.map(\.imageURL))
        }
    }

    func loadNooks() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        isLoadingNooks = true
        nooks = (try? await nookService.getUserNooks(userId: userId)) ?? []
        isLoadingNooks = false
        hasLoadedNooks = true
    }

    func trackMedia(
        mediaItemId: UUID,
        status: TrackingStatus,
        progress: Int = 0,
        score: Double? = nil
    ) async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        do {
            try await trackingService.track(
                userId: userId,
                mediaItemId: mediaItemId,
                status: status.dbValue,
                progress: progress,
                score: score
            )
            await loadLibrary()
        } catch {
            self.error = AppError(from: error)
        }
    }

    func updateTracking(
        trackingId: UUID,
        status: TrackingStatus?,
        progress: Int?,
        score: Double?
    ) async {
        do {
            try await trackingService.updateTracking(
                trackingId: trackingId,
                status: status?.dbValue,
                progress: progress,
                score: score
            )
            await loadLibrary()
        } catch {
            self.error = AppError(from: error)
        }
    }

    func removeTracking(trackingId: UUID) async {
        do {
            try await trackingService.removeTracking(trackingId: trackingId)
            await loadLibrary()
        } catch {
            self.error = AppError(from: error)
        }
    }
}
