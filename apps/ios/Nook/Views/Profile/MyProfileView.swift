import Supabase
import SwiftUI

struct MyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile = UserProfile.sampleOwn
    @State private var selectedTab: ProfileTab = .tracked
    @State private var showEditProfile = false
    @State private var recentTracked: [TrackedMediaItem] = []

    var body: some View {
        ZStack(alignment: .top) {
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

            navigationButtons
        }
        .background(Color.nook.profileBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.nook.profileBackground)
        }
        .task { await loadProfile() }
        .refreshable { await loadProfile() }
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
                            Image("camera-bold")
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
                        placeholderColor: nil,
                        rating: item.score.map { $0 / 2.0 }
                    ))
                }
            }
        }
    }

    // MARK: - Reviews Tab

    private var reviewsContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<2) { i in
                ProfileReviewCard(
                    reviewerName: profile.displayName,
                    mediaTitle: i == 0 ? "Iron & Ember" : "The Cloud Weaver",
                    content: i == 0
                        ? "\"An incredible journey that redefines what cozy RPGs can be. The world-building is top-notch.\""
                        : "\"Beautiful animation and a story that keeps you guessing. Every episode is a masterpiece.\"",
                    rating: i == 0 ? 4.0 : 4.5,
                    likes: i == 0 ? "24" : "18",
                    comments: i == 0 ? "8" : "5",
                    placeholderColor: i == 0
                        ? Color(hex: 0xC4956E) : Color(hex: 0xD4C4A8)
                )
            }
        }
    }

    // MARK: - Nooks Tab

    private var nooksContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<2) { i in
                ProfileNookCard(
                    title: i == 0 ? "Cozy Games to Wind Down" : "Sci-Fi Essentials",
                    itemCount: i == 0 ? 18 : 32,
                    likes: i == 0 ? 245 : 512,
                    placeholderColor: i == 0
                        ? Color(hex: 0xB8D4C8) : Color(hex: 0xA8C4D4)
                )
            }
        }
    }

    // MARK: - Posts Tab

    private var postsContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<2) { i in
                ProfilePostCard(
                    authorName: profile.displayName,
                    clubName: i == 0 ? "Anime Collective" : "Cozy Gamers",
                    content: i == 0
                        ? "Just finished Frieren and I'm emotionally devastated in the best way possible. That finale..."
                        : "Anyone else playing the new update? The garden mechanic is exactly what I needed.",
                    likes: i == 0 ? "42" : "31",
                    comments: i == 0 ? "15" : "9",
                    timeAgo: i == 0 ? "2h ago" : "1d ago"
                )
            }
        }
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
                followersCount: profile.followersCount,
                followingCount: profile.followingCount,
                trackedMedia: stats.trackedCount,
                reviewsWritten: stats.reviewCount,
                curatedNooks: stats.nookCount,
                clubs: stats.clubCount,
                tasteIdentity: profile.tasteIdentity,
                recentActivity: profile.recentActivity,
                isCurrentUser: true
            )

            // Load recent tracked items
            let trackingService = TrackingService()
            recentTracked = (try? await trackingService.getLibrary(userId: user.id)) ?? []
        } catch {
            // Fall back to auth metadata
            if let name = user.userMetadata["full_name"]?.value as? String {
                profile = UserProfile(
                    id: user.id.uuidString,
                    displayName: name,
                    username: "@\(name.lowercased().replacingOccurrences(of: " ", with: ""))",
                    bio: profile.bio,
                    avatarURL: (user.userMetadata["avatar_url"]?.value as? String).flatMap {
                        URL(string: $0)
                    },
                    followersCount: profile.followersCount,
                    followingCount: profile.followingCount,
                    trackedMedia: profile.trackedMedia,
                    reviewsWritten: profile.reviewsWritten,
                    curatedNooks: profile.curatedNooks,
                    clubs: profile.clubs,
                    tasteIdentity: profile.tasteIdentity,
                    recentActivity: profile.recentActivity,
                    isCurrentUser: true
                )
            }
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
            RoundedRectangle(cornerRadius: 17.78)
                .fill(activity.placeholderColor ?? Color.nook.secondary)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.label)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(0.55)
                    .foregroundStyle(Color.nook.profileActivityLabel)

                Text(activity.title)
                    .font(NookFont.outfitLabelBold)
                    .foregroundStyle(Color.nook.profileActivityTitle)

                if let rating = activity.rating {
                    ratingStars(rating)
                } else if !activity.tags.isEmpty {
                    tagRow
                }
            }

            Spacer()
        }
        .padding(13)
    }

    private func ratingStars(_ rating: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(
                        Double(index) < rating
                            ? Color.nook.accent
                            : Color.nook.accent.opacity(0.3)
                    )
            }
        }
        .padding(.top, 2)
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

                            Text(mediaTitle)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 10, relativeTo: .caption2))
                                .foregroundStyle(Color.nook.cardTitle)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text(String(format: "%.1f", rating))
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
}

// MARK: - Nook Card

struct ProfileNookCard: View {
    let title: String
    let itemCount: Int
    let likes: Int
    let placeholderColor: Color

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: NookRadii.sm)
                .fill(placeholderColor)
                .frame(width: 80, height: 80)

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
