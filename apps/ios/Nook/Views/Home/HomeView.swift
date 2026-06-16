import Supabase
import SwiftUI

struct HomeView: View {
    var router: AppRouter
    // Feed data lives in a store owned by MainTabView, so it survives tab
    // switches and renders instantly on return instead of refetching.
    var store: HomeStore
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AdManager.self) private var ads
    @State private var unreadNotifCount: Int = 0
    private let badgeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}
    var onStartTracking: () -> Void = {}
    var onSeeAllTracking: () -> Void = {}

    // Blocked users are filtered out of every feed at render time, so blocking
    // someone makes their content vanish here immediately (see BlockStore).
    private var visibleTrending: [ReviewItem] {
        store.trendingReviews.filter { !BlockStore.shared.isBlocked($0.reviewerUserId) }
    }
    private var visiblePopularNooks: [NookItem] {
        store.popularNooks.filter { !BlockStore.shared.isBlocked($0.ownerUserId) }
    }

    var body: some View {
        scrollContent
            .background(Color.nook.background)
            .modifier(HomeTopBar(
                avatarURL: router.currentUserAvatarURL,
                displayName: router.currentUserDisplayName,
                notifBadgeCount: unreadNotifCount,
                onAvatarTapped: onAvatarTapped,
                onNotificationsTapped: onNotificationsTapped
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                // Renders cached feeds instantly; refreshes in the background only
                // if missing or stale (see HomeStore).
                store.loadIfNeeded()
                await loadUnreadCount()
                // Long-lived: updates the badge live until this view's task is
                // cancelled. The 60s timer below stays as a fallback if Realtime drops.
                await observeNotifications()
            }
            .onReceive(badgeTimer) { _ in
                Task { await loadUnreadCount() }
            }
            .refreshable {
                await router.refreshProfile()
                await store.reload()
                await loadUnreadCount()
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !store.continueTracking.isEmpty {
                    ContinueTrackingSection(items: store.continueTracking, onSeeAll: onSeeAllTracking)
                        .padding(.top, 8)
                } else {
                    Button(action: onStartTracking) {
                        HomeEmptyCard(
                            icon: "bookmark-simple-fill",
                            title: "Start tracking",
                            subtitle: "Search for media and track your progress"
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                }

                if !visibleTrending.isEmpty {
                    TrendingReviewsSection(items: visibleTrending)
                        .padding(.top, 32)
                }

                // One native ad between sections (free tier only).
                NativeAdFeedSlot(key: Self.homeAdKey)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                if !visiblePopularNooks.isEmpty {
                    PopularNooksSection(items: visiblePopularNooks)
                        .padding(.top, 32)
                }

                // Second native ad at the bottom of the home scroll.
                NativeAdFeedSlot(key: Self.homeAdKey2)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
        .task {
            guard !subscriptions.isPlus else { return }
            ads.requestAd(for: Self.homeAdKey)
            ads.requestAd(for: Self.homeAdKey2)
        }
    }

    private static let homeAdKey = "home-feed"
    private static let homeAdKey2 = "home-feed-2"

    private func loadUnreadCount() async {
        let notifService = NotificationService()
        unreadNotifCount = (try? await notifService.getUnreadCount()) ?? 0
        PushService.shared.setBadge(unreadNotifCount)
    }

    /// Subscribe to live notification inserts and refresh the badge on each one.
    /// Runs for the lifetime of the view's `.task` and tears the channel down on exit.
    private func observeNotifications() async {
        let notifService = NotificationService()
        guard let stream = try? await notifService.observeNewNotifications() else { return }
        for await _ in stream {
            await loadUnreadCount()
        }
    }
}

// MARK: - Home Store

/// Owns the Home feed (continue-tracking, trending reviews, popular nooks) for
/// the lifetime of the session so switching tabs no longer refetches.
///
/// Strategy is stale-while-revalidate: `loadIfNeeded()` shows whatever is already
/// loaded immediately and only hits the network when there's nothing yet or the
/// data has gone stale. Owned by `MainTabView` and warmed on app entry, so the
/// first visit to Home is already populated.
@MainActor
@Observable
final class HomeStore {
    private(set) var continueTracking: [TrackingItem] = []
    private(set) var trendingReviews: [ReviewItem] = []
    private(set) var popularNooks: [NookItem] = []
    private(set) var hasLoaded = false

    private var lastRefresh: Date?
    private let staleAfter: TimeInterval = 120
    private var inFlight: Task<Void, Never>?

    private let trackingService = TrackingService()
    private let reviewService = ReviewService()
    private let nookService = NookService()

    nonisolated(unsafe) private var changeObserver: NSObjectProtocol?

    init() {
        // Keep "Continue tracking" in sync when media is tracked/edited from any
        // other surface (Search, Library, detail). The store outlives the Home
        // view, so we observe here rather than in the view.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .trackedMediaDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    private var isStale: Bool {
        guard let lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > staleAfter
    }

    /// Refresh in the background only if we have nothing yet or the data is stale.
    /// Returns immediately; existing data keeps rendering while the refresh runs.
    func loadIfNeeded() {
        guard !hasLoaded || isStale else { return }
        refresh()
    }

    /// Fire-and-forget background refresh, coalescing concurrent callers.
    func refresh() {
        guard inFlight == nil else { return }
        inFlight = Task { [weak self] in
            await self?.performRefresh()
            self?.inFlight = nil
        }
    }

    /// Awaitable refresh for pull-to-refresh (keeps the spinner up until done).
    func reload() async {
        inFlight?.cancel()
        inFlight = nil
        await performRefresh()
    }

    private func performRefresh() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }

        // Kick all three off concurrently; await each where we apply it.
        async let trackingResult = trackingService.getLibrary(userId: userId)
        async let trendingResult = reviewService.getTrendingReviews(limit: 5)
        async let nooksResult = nookService.getPopularNooks(limit: 10)

        // Only overwrite on success, so a transient failure never blanks the feed.
        if let items = try? await trackingResult {
            continueTracking = items
                .filter { $0.status == "in_progress" }
                .prefix(10)
                .map { TrackingItem(from: $0) }
        }
        if let reviews = try? await trendingResult {
            trendingReviews = reviews.map { ReviewItem(from: $0) }
        }
        if let summaries = try? await nooksResult {
            popularNooks = summaries.map { NookItem(from: $0) }
        }

        // Warm poster + avatar images so they're already decoded when the feed renders.
        ImagePrefetcher.prefetch(
            continueTracking.map(\.imageURL)
                + trendingReviews.map(\.mediaImageURL)
                + trendingReviews.map(\.reviewerAvatarURL)
                + popularNooks.map(\.imageURL)
        )

        hasLoaded = true
        lastRefresh = Date()
    }
}

// MARK: - Top bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct HomeTopBar: ViewModifier {
    let avatarURL: URL?
    var displayName: String = ""
    var notifBadgeCount: Int = 0
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                HomeHeaderView(
                    avatarURL: avatarURL,
                    displayName: displayName,
                    notifBadgeCount: notifBadgeCount,
                    onAvatarTapped: onAvatarTapped,
                    onNotificationsTapped: onNotificationsTapped
                )
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                HomeHeaderView(
                    avatarURL: avatarURL,
                    displayName: displayName,
                    notifBadgeCount: notifBadgeCount,
                    onAvatarTapped: onAvatarTapped,
                    onNotificationsTapped: onNotificationsTapped
                )
                .background(Color.nook.background)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }
}

// SoftScrollEdge is defined in SearchView.swift (shared)

// MARK: - Home Empty Card

struct HomeEmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.nook.searchEmptyIcon)

            Text(title)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.sectionTitle)

            Text(subtitle)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.cardSubtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                .stroke(Color.nook.border, lineWidth: 1)
        }
    }
}

// MARK: - JSON value helper

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }
}

#Preview {
    HomeView(router: AppRouter(), store: HomeStore())
        .environment(SubscriptionManager.shared)
        .environment(AdManager.shared)
}
