import SwiftUI

// One of a user's club posts, paired with the club it was posted in (for the label).
private struct ProfilePostEntry: Identifiable, Hashable {
    let post: ClubPost
    let clubName: String
    var id: UUID { post.id }
}

struct OtherProfileView: View {
    private let userId: UUID?
    @State private var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ProfileTab = .tracked
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var recentActivity: [ProfileActivity] = []
    @State private var userReviews: [Review] = []
    @State private var userNooks: [NookSummary] = []
    @State private var userPosts: [ProfilePostEntry] = []
    @State private var showReportSheet = false
    @State private var showReportConfirmation = false

    private let moderation = ModerationService()

    init(profile: UserProfile) {
        self.userId = UUID(uuidString: profile.id)
        self._profile = State(initialValue: profile)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isLoading {
                profileLoadingState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileHeader
                        actionButtons
                            .padding(.top, 16)
                        tabBar
                            .padding(.top, 24)
                        if selectedTab == .tracked {
                            statsGrid
                                .padding(.top, 24)
                                .transition(.identity)
                        }
                        tabContentSection
                            .padding(.top, selectedTab == .tracked ? 32 : 24)
                            .padding(.bottom, 40)
                            .animation(nil, value: selectedTab)
                    }
                }
            }

            navigationButtons
        }
        .background(Color.nook.profileBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(subject: "account") { reason, details in
                submitReport(reason: reason, details: details)
            }
        }
        .alert("Report received", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for helping keep Nook safe. We'll review this account.")
        }
        .task {
            await loadProfile()
        }
    }

    // MARK: - Data

    private func loadProfile() async {
        guard let userId else {
            isLoading = false
            return
        }

        let profileService = ProfileService()

        // Kick everything off in parallel.
        async let profileDataT = profileService.getProfile(userId: userId)
        async let statsT = profileService.getStats(userId: userId)
        async let followingFlagT = profileService.isFollowing(userId: userId)
        async let followerCountT = profileService.getFollowerCount(userId: userId)
        async let followingCountT = profileService.getFollowingCount(userId: userId)
        async let activityT = profileService.getRecentActivity(userId: userId, limit: 5)
        async let reviewsT = ReviewService().getReviewsByUser(userId: userId)
        async let nooksT = NookService().getUserNooks(userId: userId)
        async let postsT = ClubService().getPostsByUser(userId: userId)

        // Header + stat grid.
        let data = try? await profileDataT
        let stats = try? await statsT
        profile = mergedProfile(base: profile, data: data, stats: stats)

        // Follow state + counts.
        isFollowing = (try? await followingFlagT) ?? false
        followerCount = (try? await followerCountT) ?? profile.followersCount
        followingCount = (try? await followingCountT) ?? profile.followingCount

        // Tabs.
        recentActivity = ((try? await activityT) ?? []).map { row in
            let status = TrackingStatus.from(dbValue: row.status)
            return ProfileActivity(
                label: status?.label.uppercased() ?? row.status.uppercased(),
                title: row.title ?? "",
                imageName: "",
                imageURL: row.imageUrl.flatMap { URL(string: $0) },
                rating: row.score
            )
        }
        userReviews = (try? await reviewsT) ?? []
        userNooks = (try? await nooksT) ?? []
        userPosts = await buildPosts(from: (try? await postsT) ?? [])

        isLoading = false
    }

    /// Fold the freshly fetched profile + stats onto the lightweight profile we were
    /// navigated with (which only carries an id + display name).
    private func mergedProfile(base: UserProfile, data: UserProfileData?, stats: UserStats?) -> UserProfile {
        UserProfile(
            id: base.id,
            displayName: data?.fullName ?? base.displayName,
            username: data?.username.map { "@\($0)" } ?? base.username,
            bio: data?.bio ?? base.bio,
            avatarURL: data?.avatarURL ?? base.avatarURL,
            followersCount: base.followersCount,
            followingCount: base.followingCount,
            trackedMedia: stats?.trackedCount ?? base.trackedMedia,
            reviewsWritten: stats?.reviewCount ?? base.reviewsWritten,
            curatedNooks: stats?.nookCount ?? base.curatedNooks,
            clubs: stats?.clubCount ?? base.clubs,
            tasteIdentity: base.tasteIdentity,
            recentActivity: base.recentActivity,
            isCurrentUser: false
        )
    }

    /// Resolve each post's club (name + accent) so the Posts tab can label and theme it.
    private func buildPosts(from models: [ClubPostModel]) async -> [ProfilePostEntry] {
        guard !models.isEmpty else { return [] }

        let clubIds = Array(Set(models.map { $0.clubId }))
        let briefs = (try? await ClubService().getClubBriefs(ids: clubIds)) ?? [:]

        return models.map { model in
            let brief = briefs[model.clubId]
            let themeHex = ClubItem.parseHex(brief?.themeColor)
                ?? brief.map { ClubCategory.from(dbValue: $0.category).accentHex }
            let post = ClubPost(from: model, isLiked: false, themeHex: themeHex)
            return ProfilePostEntry(post: post, clubName: brief?.name ?? "a club")
        }
    }

    private func submitReport(reason: ReportReason, details: String?) {
        guard let userId else { return }
        Task {
            try? await moderation.report(
                targetType: "user",
                targetId: userId,
                reportedUserId: userId,
                reason: reason,
                details: details
            )
        }
        showReportConfirmation = true
    }

    private func blockUser() {
        guard let userId else { return }
        // Block, then dismiss. Awaiting first defers the dismiss past the menu's
        // own dismissal — calling dismiss() synchronously inside a Menu action is
        // swallowed while the menu is still closing.
        Task { @MainActor in
            await BlockStore.shared.block(userId: userId)
            dismiss()
        }
    }

    private func toggleFollow() {
        guard let userId, !isFollowLoading else { return }

        let wasFollowing = isFollowing
        isFollowLoading = true
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            isFollowing.toggle()
            followerCount = max(followerCount + (wasFollowing ? -1 : 1), 0)
        }

        Task { @MainActor in
            let profileService = ProfileService()
            do {
                if wasFollowing {
                    try await profileService.unfollow(userId: userId)
                } else {
                    try await profileService.follow(userId: userId)
                }
            } catch {
                // Roll back the optimistic update if the write failed.
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    isFollowing = wasFollowing
                    followerCount = max(followerCount + (wasFollowing ? 1 : -1), 0)
                }
            }
            isFollowLoading = false
        }
    }

    // MARK: - Navigation Buttons (MediaDetail-style overlay)

    private var navigationButtons: some View {
        HStack {
            navButton(icon: "caret-left-bold") {
                dismiss()
            }

            Spacer()

            // Only show moderation actions when we have a real user id to act on.
            if userId != nil {
                moreMenu
            }
        }
        .padding(.horizontal, 16)
    }

    private var moreMenu: some View {
        Menu {
            Button(role: .destructive) {
                showReportSheet = true
            } label: {
                sizedMenuLabel("Report", icon: "flag")
            }

            Button(role: .destructive) {
                blockUser()
            } label: {
                sizedMenuLabel("Block user", icon: "user-minus")
            }
        } label: {
            navMenuLabel(icon: "dots-three-bold")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .frame(width: 48, height: 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func navMenuLabel(icon: String) -> some View {
        if #available(iOS 26, *) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .glassEffect(.regular, in: .circle)
        } else {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        } else {
            Button(action: action) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            avatarView
                .frame(width: 112, height: 112)
                .padding(.top, 48)

            Text(profile.displayName)
                .font(NookFont.outfitHeadingMedium)
                .foregroundStyle(Color.nook.profileName)

            Text(profile.username)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.profileUsername)

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.profileBio)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }

            followerCountsView
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var avatarView: some View {
        AsyncImage(url: profile.avatarURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Circle()
                    .fill(Color(hex: 0x8B6FA0))
                    .overlay {
                        Text(String(profile.displayName.prefix(1)).uppercased())
                            .font(NookFont.headingMediumBold)
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: 112, height: 112)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.nook.profileAvatarBorder, lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .shadow(color: .black.opacity(0.1), radius: 6, y: 4)
    }

    private var followerCountsView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(formatCount(followerCount))
                    .font(NookFont.outfitFollowerCount)
                    .foregroundStyle(Color.nook.profileStatValue)
                Text("Followers")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.profileStatLabel)
            }
            .frame(width: 55)

            Color.nook.profileStatDivider
                .frame(width: 1, height: 32)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                Text(formatCount(followingCount))
                    .font(NookFont.outfitFollowerCount)
                    .foregroundStyle(Color.nook.profileStatValue)
                Text("Following")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.profileStatLabel)
            }
            .frame(width: 55)
        }
    }

    // MARK: - Action Button (Follow)

    private var actionButtons: some View {
        followButton
            .padding(.horizontal, 24)
    }

    private var followButton: some View {
        Button(action: toggleFollow) {
            HStack(spacing: 8) {
                if !isFollowing {
                    Image("user-plus-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }

                Text(isFollowing ? "Following" : "Follow")
                    .font(NookFont.labelSmall)
            }
            .foregroundStyle(
                isFollowing
                    ? Color.nook.profileFollowingText
                    : .white
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        isFollowing
                            ? Color.nook.profileFollowingButton
                            : Color.nook.profileFollowButton
                    )
            )
            .overlay {
                if isFollowing {
                    Capsule()
                        .stroke(Color.nook.profileStatDivider, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Bar (Club Detail style chips)

    private var tabBar: some View {
        ProfileChipTabBar(selectedTab: $selectedTab)
            .padding(.horizontal, 24)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ProfileStatCard(
                icon: "bookmark-simple-fill",
                value: profile.trackedMedia,
                label: "Tracked Media",
                iconColor: Color.nook.profileStatTracked,
                iconBackground: Color.nook.profileStatTrackedBg
            )
            ProfileStatCard(
                icon: "pencil-simple-line-fill",
                value: profile.reviewsWritten,
                label: "Reviews Written",
                iconColor: Color.nook.profileStatReviews,
                iconBackground: Color.nook.profileStatReviewsBg
            )
            ProfileStatCard(
                icon: "squares-four-fill",
                value: profile.curatedNooks,
                label: "Curated Nooks",
                iconColor: Color.nook.profileStatNooks,
                iconBackground: Color.nook.profileStatNooksBg
            )
            ProfileStatCard(
                icon: "users-three-fill",
                value: profile.clubs,
                label: "Clubs",
                iconColor: Color.nook.profileStatCommunities,
                iconBackground: Color.nook.profileStatCommunitiesBg
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Tab Content

    private var tabContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedTab == .tracked ? "Recently Active" : selectedTab.rawValue)
                .font(NookFont.outfitLabel)
                .foregroundStyle(Color.nook.profileSectionTitle)

            switch selectedTab {
            case .tracked:
                trackedContent
            case .reviews:
                reviewsContent
            case .nooks:
                nooksContent
            case .posts:
                postsContent
            }
        }
        .padding(.horizontal, 24)
    }

    private var trackedContent: some View {
        VStack(spacing: 16) {
            if recentActivity.isEmpty {
                emptyState(
                    title: "No activity yet",
                    subtitle: "This user hasn't tracked anything recently"
                )
            } else {
                ForEach(recentActivity) { activity in
                    ProfileActivityCard(activity: activity)
                }
            }
        }
    }

    private var reviewsContent: some View {
        VStack(spacing: 12) {
            if userReviews.isEmpty {
                emptyState(title: "No reviews yet", subtitle: "Reviews will appear here")
            } else {
                ForEach(userReviews) { review in
                    NavigationLink(value: ReviewItem(from: review)) {
                        ProfileReviewCard(
                            reviewerName: review.authorName,
                            mediaTitle: review.mediaTitle ?? "",
                            content: review.body,
                            rating: review.rating,
                            likes: "\(review.likesCount)",
                            comments: "0",
                            placeholderColor: Color(hex: 0xC4956E)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nooksContent: some View {
        VStack(spacing: 12) {
            if userNooks.isEmpty {
                emptyState(
                    title: "No nooks yet",
                    subtitle: "This user hasn't shared any nooks"
                )
            } else {
                ForEach(userNooks) { summary in
                    NavigationLink(value: NookItem(from: summary)) {
                        ProfileNookCard(
                            title: summary.name,
                            itemCount: summary.itemCount,
                            likes: summary.likesCount,
                            previewImageURLs: summary.previewImageURLs
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var postsContent: some View {
        VStack(spacing: 12) {
            if userPosts.isEmpty {
                emptyState(
                    title: "No posts yet",
                    subtitle: "This user hasn't posted in any clubs"
                )
            } else {
                ForEach(userPosts) { entry in
                    NavigationLink(value: entry.post) {
                        ProfilePostCard(
                            authorName: profile.displayName,
                            clubName: entry.clubName,
                            content: entry.post.body,
                            likes: entry.post.likes,
                            comments: entry.post.comments,
                            timeAgo: entry.post.timeAgo
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailMeta)
            Text(subtitle)
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Loading State

    private var profileLoadingState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header skeleton — matches profileHeader layout
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 112, height: 112)
                        .padding(.top, 48)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 160, height: 22)

                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 90, height: 14)

                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.nook.searchShimmerBase)
                            .frame(width: 260, height: 13)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.nook.searchShimmerBase)
                            .frame(width: 200, height: 13)
                    }
                    .padding(.top, 4)

                    // Follower counts skeleton
                    HStack(spacing: 33) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.nook.searchShimmerBase)
                                .frame(width: 55, height: 32)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Follow button skeleton
                Capsule()
                    .fill(Color.nook.searchShimmerBase)
                    .frame(height: 44)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Tab bar skeleton
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.nook.searchShimmerBase)
                            .frame(width: i == 0 ? 70 : 80, height: 36)
                    }
                }
                .padding(.top, 24)

                // Stats grid skeleton — matches 2-column grid
                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                            .fill(Color.nook.searchShimmerBase)
                            .frame(height: 80)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return "\(count)"
    }
}

#Preview {
    NavigationStack {
        OtherProfileView(profile: .sampleOther)
    }
}
