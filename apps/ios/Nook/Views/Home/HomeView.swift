import Supabase
import SwiftUI

struct HomeView: View {
    @State private var avatarURL: URL?
    @State private var popularNooks: [NookItem] = []
    @State private var trendingReviews: [ReviewItem] = []
    @State private var continueTracking: [TrackingItem] = []
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}

    var body: some View {
        scrollContent
            .background(Color.nook.background)
            .modifier(HomeTopBar(
                avatarURL: avatarURL,
                onAvatarTapped: onAvatarTapped,
                onNotificationsTapped: onNotificationsTapped
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await loadUserProfile()
                await loadContinueTracking()
                await loadTrendingReviews()
                await loadPopularNooks()
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ContinueTrackingSection(items: continueTracking.isEmpty ? ContinueTrackingSection.mockItems : continueTracking)
                    .padding(.top, 8)

                ActivityFeedSection(items: ActivityFeedSection.mockItems)
                    .padding(.top, 32)

                TrendingReviewsSection(items: trendingReviews.isEmpty ? TrendingReviewsSection.mockItems : trendingReviews)
                    .padding(.top, 32)

                PopularNooksSection(items: popularNooks.isEmpty ? PopularNooksSection.mockItems : popularNooks)
                    .padding(.top, 32)
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
    }

    private func loadUserProfile() async {
        guard let user = try? await supabase.auth.session.user else { return }

        let profileService = ProfileService()
        if let profile = try? await profileService.getProfile(userId: user.id),
           let url = profile.avatarURL {
            avatarURL = url
            return
        }

        if let urlString = user.userMetadata["avatar_url"]?.stringValue {
            avatarURL = URL(string: urlString)
        }
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
        if let rows = try? await nookService.getPopularNooks(limit: 10) {
            popularNooks = rows.map { NookItem(from: $0) }
        }
    }
}

// MARK: - Top bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct HomeTopBar: ViewModifier {
    let avatarURL: URL?
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                HomeHeaderView(
                    avatarURL: avatarURL,
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
    HomeView()
}
