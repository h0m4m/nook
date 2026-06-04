import SwiftUI

struct OtherProfileView: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ProfileTab = .tracked
    @State private var isFollowing = false
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var userReviews: [Review] = []
    @State private var userNooks: [NookSummary] = []
    @State private var showReportSheet = false
    @State private var showReportConfirmation = false

    private let moderation = ModerationService()

    var body: some View {
        ZStack(alignment: .top) {
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
            await loadFollowState()
        }
    }

    private func submitReport(reason: ReportReason, details: String?) {
        guard let userId = UUID(uuidString: profile.id) else { return }
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
        guard let userId = UUID(uuidString: profile.id) else { return }
        // Block, then dismiss. Awaiting first defers the dismiss past the menu's
        // own dismissal — calling dismiss() synchronously inside a Menu action is
        // swallowed while the menu is still closing.
        Task { @MainActor in
            await BlockStore.shared.block(userId: userId)
            dismiss()
        }
    }

    private func loadFollowState() async {
        guard let userId = UUID(uuidString: profile.id) else { return }
        let profileService = ProfileService()
        isFollowing = (try? await profileService.isFollowing(userId: userId)) ?? false
        followerCount = (try? await profileService.getFollowerCount(userId: userId)) ?? profile.followersCount
        followingCount = (try? await profileService.getFollowingCount(userId: userId)) ?? profile.followingCount

        let reviewService = ReviewService()
        userReviews = (try? await reviewService.getReviewsByUser(userId: userId)) ?? []

        let nookService = NookService()
        userNooks = (try? await nookService.getUserNooks(userId: userId)) ?? []
    }

    // MARK: - Navigation Buttons (MediaDetail-style overlay)

    private var navigationButtons: some View {
        HStack {
            navButton(icon: "caret-left-bold") {
                dismiss()
            }

            Spacer()

            // Only show moderation actions when we have a real user id to act on.
            if UUID(uuidString: profile.id) != nil {
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

            Text(profile.bio)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.profileBio)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
                .padding(.top, 4)

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
                Text("\(followingCount)")
                    .font(NookFont.outfitFollowerCount)
                    .foregroundStyle(Color.nook.profileStatValue)
                Text("Following")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.profileStatLabel)
            }
            .frame(width: 55)
        }
    }

    // MARK: - Action Buttons (Follow + Message)

    private var actionButtons: some View {
        followButton
            .padding(.horizontal, 24)
    }

    private var followButton: some View {
        Button {
            let wasFollowing = isFollowing
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                isFollowing.toggle()
                followerCount += wasFollowing ? -1 : 1
            }

            if let userId = UUID(uuidString: profile.id) {
                Task {
                    let profileService = ProfileService()
                    if wasFollowing {
                        try? await profileService.unfollow(userId: userId)
                    } else {
                        try? await profileService.follow(userId: userId)
                    }
                }
            }
        } label: {
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

    // MARK: - Taste Identity (no icons)

    private var tasteIdentitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Taste Identity")
                .font(NookFont.outfitLabel)
                .foregroundStyle(Color.nook.profileSectionTitle)

            FlowLayout(spacing: 8) {
                ForEach(profile.tasteIdentity) { tag in
                    TasteTagView(tag: tag)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Tab Content

    private var tabContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedTab == .tracked ? "Recently Active" : selectedTab.rawValue)
                    .font(NookFont.outfitLabel)
                    .foregroundStyle(Color.nook.profileSectionTitle)

                Spacer()

                Button {} label: {
                    Text("View All")
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.profileViewAll)
                }
                .buttonStyle(.plain)
            }

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
            ForEach(profile.recentActivity) { activity in
                ProfileActivityCard(activity: activity)
            }
        }
    }

    private var reviewsContent: some View {
        VStack(spacing: 12) {
            if userReviews.isEmpty {
                VStack(spacing: 8) {
                    Text("No reviews yet")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.detailMeta)
                    Text("Reviews will appear here")
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
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
                VStack(spacing: 8) {
                    Text("No nooks yet")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.detailMeta)
                    Text("This user hasn't shared any nooks")
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
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
            ForEach(0..<2) { i in
                ProfilePostCard(
                    authorName: profile.displayName,
                    clubName: i == 0 ? "Anime Collective" : "Manga Readers",
                    content: i == 0
                        ? "Hot take: Frieren is the best anime of the decade. Fight me."
                        : "Just picked up Dandadan and I can't put it down. The art is insane.",
                    likes: i == 0 ? "156" : "78",
                    comments: i == 0 ? "42" : "19",
                    timeAgo: i == 0 ? "5h ago" : "2d ago"
                )
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
