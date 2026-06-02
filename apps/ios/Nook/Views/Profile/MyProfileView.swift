import Supabase
import SwiftUI

struct MyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    var router: AppRouter?
    @State private var profile = UserProfile.empty
    @State private var isLoading = true
    @State private var selectedTab: ProfileTab = .tracked
    @State private var showEditProfile = false
    @State private var recentTracked: [TrackedMediaItem] = []
    @State private var userReviews: [Review] = []
    @State private var userNooks: [NookSummary] = []

    var body: some View {
        ZStack(alignment: .top) {
            if isLoading {
                profileLoadingState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileHeader
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
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(onSaved: {
                await router?.refreshProfile()
                await loadProfile()
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.nook.profileBackground)
        }
        .task { await loadProfile() }
        .refreshable { await loadProfile() }
        .onReceive(NotificationCenter.default.publisher(for: .nooksDidChange)) { _ in
            Task { await loadProfile() }
        }
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
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Tab bar skeleton — matches tabBar padding
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

    // MARK: - Navigation Buttons (MediaDetail-style overlay)

    private var navigationButtons: some View {
        HStack {
            navButton(icon: "caret-left-bold") {
                dismiss()
            }

            Spacer()

            navButton(icon: "export") {}
        }
        .padding(.horizontal, 16)
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
            ZStack(alignment: .bottomTrailing) {
                avatarView
                    .frame(width: 112, height: 112)

                Button { showEditProfile = true } label: {
                    Circle()
                        .fill(Color.nook.profileAvatarEditBg)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .stroke(Color.nook.profileAvatarBorder, lineWidth: 2)
                        }
                        .overlay {
                            Image("pencil-simple-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
            }
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
                    .fill(Color.nook.accent)
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
                Text(formatCount(profile.followersCount))
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
                Text("\(profile.followingCount)")
                    .font(NookFont.outfitFollowerCount)
                    .foregroundStyle(Color.nook.profileStatValue)
                Text("Following")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.profileStatLabel)
            }
            .frame(width: 55)
        }
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

    // MARK: - Tracked Tab (Activity Cards)

    private var trackedContent: some View {
        VStack(spacing: 16) {
            if recentTracked.isEmpty {
                ForEach(profile.recentActivity) { activity in
                    ProfileActivityCard(activity: activity)
                }
            } else {
                ForEach(recentTracked.prefix(5)) { item in
                    let status = TrackingStatus.from(dbValue: item.status)
                    ProfileActivityCard(activity: ProfileActivity(
                        label: status?.label.uppercased() ?? item.status.uppercased(),
                        title: item.title,
                        imageName: "",
                        imageURL: item.imageURL,
                        rating: item.score
                    ))
                }
            }
        }
    }

    // MARK: - Reviews Tab

    private var reviewsContent: some View {
        VStack(spacing: 12) {
            if userReviews.isEmpty {
                VStack(spacing: 8) {
                    Text("No reviews yet")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.detailMeta)
                    Text("Your reviews will appear here")
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

    // MARK: - Nooks Tab

    private var nooksContent: some View {
        VStack(spacing: 12) {
            if userNooks.isEmpty {
                VStack(spacing: 8) {
                    Text("No nooks yet")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.detailMeta)
                    Text("Tap + to create your first nook")
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
                            coverURL: summary.coverURL
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Posts Tab

    private var postsContent: some View {
        VStack(spacing: 8) {
            Text("No posts yet")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailMeta)
            Text("Your posts will appear here")
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Data

    private func loadProfile() async {
        guard let user = try? await supabase.auth.session.user else { return }
        let profileService = ProfileService()

        do {
            let data = try await profileService.getProfile(userId: user.id)
            let stats = try await profileService.getStats(userId: user.id)

            let displayName = data.fullName
                ?? (user.userMetadata["full_name"]?.value as? String)
                ?? "User"
            let usernameDisplay = data.username.map { "@\($0)" }
                ?? "@\(displayName.lowercased().replacingOccurrences(of: " ", with: ""))"

            profile = UserProfile(
                id: user.id.uuidString,
                displayName: displayName,
                username: usernameDisplay,
                bio: data.bio ?? "",
                avatarURL: data.avatarURL,
                followersCount: 0,
                followingCount: 0,
                trackedMedia: stats.trackedCount,
                reviewsWritten: stats.reviewCount,
                curatedNooks: stats.nookCount,
                clubs: stats.clubCount,
                tasteIdentity: [],
                recentActivity: [],
                isCurrentUser: true
            )

            // Load recent tracked items, reviews, and nooks in parallel
            async let trackedItems = TrackingService().getLibrary(userId: user.id)
            async let reviews = ReviewService().getReviewsByUser(userId: user.id)
            async let nooks = NookService().getUserNooks(userId: user.id)

            recentTracked = (try? await trackedItems) ?? []
            userReviews = (try? await reviews) ?? []
            userNooks = (try? await nooks) ?? []

            isLoading = false
        } catch {
            // Fall back to auth metadata
            if let name = user.userMetadata["full_name"]?.value as? String {
                profile = UserProfile(
                    id: user.id.uuidString,
                    displayName: name,
                    username: "@\(name.lowercased().replacingOccurrences(of: " ", with: ""))",
                    bio: "",
                    avatarURL: (user.userMetadata["avatar_url"]?.value as? String)
                        .flatMap { URL(string: $0) },
                    followersCount: 0,
                    followingCount: 0,
                    trackedMedia: 0,
                    reviewsWritten: 0,
                    curatedNooks: 0,
                    clubs: 0,
                    tasteIdentity: [],
                    recentActivity: [],
                    isCurrentUser: true
                )
            }
            isLoading = false
        }
    }

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

// MARK: - Club-Detail-Style Chip Tab Bar

struct ProfileChipTabBar: View {
    @Binding var selectedTab: ProfileTab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    tabChip(tab)
                }
            }
        }
    }

    @ViewBuilder
    private func tabChip(_ tab: ProfileTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(isSelected ? .white : Color.nook.profileName)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.nook.primary : .clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : Color.nook.profileStatCardBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card

struct ProfileStatCard: View {
    let icon: String
    let value: Int
    let label: String
    let iconColor: Color
    let iconBackground: Color

    var body: some View {
        cardContent
            .background(Color.nook.profileStatCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.md))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.md)
                    .stroke(Color.nook.profileStatCardBorder, lineWidth: 1)
            }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(iconBackground)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(iconColor)
                }

            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(NookFont.outfitStatValue)
                    .foregroundStyle(Color.nook.profileStatValue)
                Text(label)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.profileStatLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
    }
}

// MARK: - Taste Tag (no icon)

struct TasteTagView: View {
    let tag: TasteTag

    var body: some View {
        Text(tag.name)
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.profileName)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(tag.category.backgroundColor)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(tag.category.borderColor, lineWidth: 1)
            }
    }
}

// MARK: - Activity Card

struct ProfileActivityCard: View {
    let activity: ProfileActivity

    var body: some View {
        cardContent
            .background(Color.nook.profileActivityCard)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay {
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.nook.profileActivityCardBorder, lineWidth: 1)
            }
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            MediaPosterImage(
                url: activity.imageURL,
                width: 64,
                height: 64,
                cornerRadius: 17.78,
                fallbackColor: activity.placeholderColor ?? Color.nook.secondary
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.label)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(0.55)
                    .foregroundStyle(Color.nook.profileActivityLabel)

                Text(activity.title)
                    .font(NookFont.outfitLabelBold)
                    .foregroundStyle(Color.nook.profileActivityTitle)

                if let rating = activity.rating {
                    ratingBadge(rating)
                } else if !activity.tags.isEmpty {
                    tagRow
                }
            }

            Spacer()
        }
        .padding(13)
    }

    private func ratingBadge(_ rating: Double) -> some View {
        HStack(spacing: 2) {
            Image("star-fill")
                .renderingMode(.template)
                .resizable()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.nook.detailRatingText)

            Text(ProfileReviewCard.ratingLabel(for: rating))
                .font(NookFont.captionBold)
                .foregroundStyle(Color.nook.detailRatingText)
        }
        .padding(.horizontal, 6.5)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                .fill(Color.nook.detailRatingBadge)
        )
    }

    private var tagRow: some View {
        HStack(spacing: 7) {
            ForEach(activity.tags, id: \.self) { tag in
                Text(tag)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10, relativeTo: .caption2))
                    .foregroundStyle(Color.nook.profileActivityTagText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.nook.profileActivityTagBg)
                    .clipShape(RoundedRectangle(cornerRadius: 5.28))
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Review Card (homepage-style)

struct ProfileReviewCard: View {
    let reviewerName: String
    let mediaTitle: String
    let content: String
    let rating: Double
    let likes: String
    let comments: String
    let placeholderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.nook.mutedForeground)
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(reviewerName)
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.cardTitle)
                            .lineLimit(1)

                        HStack(spacing: 2) {
                            Text("reviewed")
                                .font(.custom("PlusJakartaSans-Regular", size: 10, relativeTo: .caption2))
                                .foregroundStyle(Color.nook.cardSubtitle)
                                .layoutPriority(1)

                            Text(mediaTitle)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 10, relativeTo: .caption2))
                                .foregroundStyle(Color.nook.cardTitle)
                                .lineLimit(1)
                        }
                        .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text(Self.ratingLabel(for: rating))
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.detailRatingText)
                }
                .padding(.horizontal, 6.5)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                        .fill(Color.nook.detailRatingBadge)
                )
            }
            .padding(.top, 21)
            .padding(.horizontal, 21)

            // Content
            Text(content)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.reviewBody)
                .lineSpacing(6)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 21)

            Spacer(minLength: 0)

            // Footer
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text(likes)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }

                HStack(spacing: 4) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text(comments)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }

                Spacer()
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 21)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                .stroke(Color.nook.profileActivityCardBorder, lineWidth: 1)
        }
    }

    static func ratingLabel(for rating: Double) -> String {
        let score = Int(rating)
        let label: String = switch score {
        case 10: "Masterpiece"
        case 9: "Excellent"
        case 8: "Great"
        case 7: "Good"
        case 6: "Decent"
        case 5: "Average"
        case 4: "Below Avg"
        case 3: "Poor"
        case 2: "Terrible"
        case 1: "Appalling"
        default: ""
        }
        return label.isEmpty ? "\(score)" : "\(score) · \(label)"
    }
}

// MARK: - Nook Card

struct ProfileNookCard: View {
    let title: String
    let itemCount: Int
    let likes: Int
    var coverURL: URL? = nil
    var placeholderColor: Color = Color.nook.secondary

    var body: some View {
        HStack(spacing: 16) {
            MediaPosterImage(
                url: coverURL,
                width: 80,
                height: 80,
                cornerRadius: NookRadii.sm,
                fallbackColor: placeholderColor
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(2)

                Text("\(itemCount) items")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)

                HStack(spacing: 4) {
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text("\(likes)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }
            }

            Spacer()

            Image("caret-left-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.nook.profileMenuChevron)
                .rotationEffect(.degrees(180))
        }
        .padding(16)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                .stroke(Color.nook.profileActivityCardBorder, lineWidth: 1)
        }
    }
}

// MARK: - Post Card

struct ProfilePostCard: View {
    let authorName: String
    let clubName: String
    let content: String
    let likes: String
    let comments: String
    let timeAgo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.nook.mutedForeground)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    Text(authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.cardTitle)
                        .lineLimit(1)

                    HStack(spacing: 2) {
                        Text("in")
                            .font(.custom("PlusJakartaSans-Regular", size: 10, relativeTo: .caption2))
                            .foregroundStyle(Color.nook.cardSubtitle)

                        Text(clubName)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 10, relativeTo: .caption2))
                            .foregroundStyle(Color.nook.activityClubName)
                    }
                }

                Spacer()

                Text(timeAgo)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }
            .padding(.top, 21)
            .padding(.horizontal, 21)

            // Content
            Text(content)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.cardTitle)
                .lineSpacing(6)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 21)

            Spacer(minLength: 0)

            // Footer
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text(likes)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }

                HStack(spacing: 4) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text(comments)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }

                Spacer()
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 21)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                .stroke(Color.nook.profileActivityCardBorder, lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        MyProfileView()
    }
}
