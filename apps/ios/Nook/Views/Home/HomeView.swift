import Supabase
import SwiftUI

struct HomeView: View {
    var router: AppRouter
    @State private var popularNooks: [NookItem] = []
    @State private var trendingReviews: [ReviewItem] = []
    @State private var continueTracking: [TrackingItem] = []
    @State private var activityFeed: [ActivityFeedItem] = []
    @State private var unreadNotifCount: Int = 0
    private let badgeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}

    var body: some View {
        scrollContent
            .background(Color.nook.background)
            .modifier(HomeTopBar(
                avatarURL: router.currentUserAvatarURL,
                notifBadgeCount: unreadNotifCount,
                onAvatarTapped: onAvatarTapped,
                onNotificationsTapped: onNotificationsTapped
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await loadContinueTracking()
                await loadActivityFeed()
                await loadTrendingReviews()
                await loadPopularNooks()
                await loadUnreadCount()
            }
            .onReceive(badgeTimer) { _ in
                Task { await loadUnreadCount() }
            }
            .refreshable {
                await router.refreshProfile()
                await loadContinueTracking()
                await loadActivityFeed()
                await loadTrendingReviews()
                await loadPopularNooks()
                await loadUnreadCount()
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !continueTracking.isEmpty {
                    ContinueTrackingSection(items: continueTracking)
                        .padding(.top, 8)
                } else {
                    HomeEmptyCard(
                        icon: "bookmark-simple-fill",
                        title: "Start tracking",
                        subtitle: "Search for media and track your progress"
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                }

                if !activityFeed.isEmpty {
                    ActivityFeedSection(items: activityFeed)
                        .padding(.top, 32)
                } else {
                    HomeEmptyCard(
                        icon: "users-three-bold",
                        title: "Your feed is empty",
                        subtitle: "Follow people to see their activity here"
                    )
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                }

                if !trendingReviews.isEmpty {
                    TrendingReviewsSection(items: trendingReviews)
                        .padding(.top, 32)
                }

                if !popularNooks.isEmpty {
                    PopularNooksSection(items: popularNooks)
                        .padding(.top, 32)
                }
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
    }

    private func loadActivityFeed() async {
        let feedService = ActivityFeedService()
        if let entries = try? await feedService.getFeed() {
            activityFeed = entries.map { ActivityFeedItem(from: $0) }
        }
    }

    private func loadUnreadCount() async {
        let notifService = NotificationService()
        unreadNotifCount = (try? await notifService.getUnreadCount()) ?? 0
    }

    private func loadContinueTracking() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        let trackingService = TrackingService()
        if let items = try? await trackingService.getLibrary(userId: userId) {
            let inProgress = items.filter { $0.status == "in_progress" }.prefix(10)
            continueTracking = inProgress.map { TrackingItem(from: $0) }
        }
    }

    private func loadTrendingReviews() async {
        let reviewService = ReviewService()
        if let reviews = try? await reviewService.getTrendingReviews(limit: 5) {
            trendingReviews = reviews.map { ReviewItem(from: $0) }
        }
    }

    private func loadPopularNooks() async {
        let nookService = NookService()
        if let summaries = try? await nookService.getPopularNooks(limit: 10) {
            popularNooks = summaries.map { NookItem(from: $0) }
        }
    }
}

// MARK: - Top bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct HomeTopBar: ViewModifier {
    let avatarURL: URL?
    var notifBadgeCount: Int = 0
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                HomeHeaderView(
                    avatarURL: avatarURL,
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
    HomeView(router: AppRouter())
}
