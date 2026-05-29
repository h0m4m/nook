import Supabase
import SwiftUI

struct HomeView: View {
    @State private var avatarURL: URL?
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
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ContinueTrackingSection(items: ContinueTrackingSection.mockItems)
                    .padding(.top, 8)

                ActivityFeedSection(items: ActivityFeedSection.mockItems)
                    .padding(.top, 32)

                TrendingReviewsSection(items: TrendingReviewsSection.mockItems)
                    .padding(.top, 32)

                PopularNooksSection(items: PopularNooksSection.mockItems)
                    .padding(.top, 32)
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
    }

    private func loadUserProfile() async {
        guard let user = try? await supabase.auth.session.user else { return }

        if let urlString = user.userMetadata["avatar_url"]?.stringValue {
            avatarURL = URL(string: urlString)
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
