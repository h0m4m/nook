import SwiftUI

// MARK: - Club Detail Models

enum ClubDetailTab: String, CaseIterable, Identifiable {
    case posts
    case polls
    case mentions
    case members

    var id: String { rawValue }

    var label: String {
        switch self {
        case .posts: "Posts"
        case .polls: "Polls"
        case .mentions: "Mentions"
        case .members: "Members"
        }
    }
}

// MARK: - Poll Model

struct PollOption: Identifiable {
    let id = UUID()
    let text: String
    var votes: Int
}

struct PostPoll {
    var options: [PollOption]
    let totalVotes: Int
    let duration: String
}

// MARK: - Club Post Model

struct ClubPost: Identifiable, Hashable {
    let id = UUID()
    let dbId: UUID?
    let authorName: String
    let timeAgo: String
    let body: String
    let boldRanges: [String]
    let imageName: String?
    let placeholderColor: Color?
    let likes: String
    let comments: String
    let poll: PostPoll?

    static func == (lhs: ClubPost, rhs: ClubPost) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(
        authorName: String,
        timeAgo: String,
        body: String,
        boldRanges: [String] = [],
        imageName: String? = nil,
        placeholderColor: Color? = nil,
        likes: String = "0",
        comments: String = "0",
        poll: PostPoll? = nil,
        dbId: UUID? = nil
    ) {
        self.authorName = authorName
        self.timeAgo = timeAgo
        self.body = body
        self.boldRanges = boldRanges
        self.imageName = imageName
        self.placeholderColor = placeholderColor
        self.likes = likes
        self.comments = comments
        self.poll = poll
        self.dbId = dbId
    }
}

struct PinnedDiscussion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let commentCount: String
    let timeAgo: String
}

// MARK: - Club Member Models

enum ClubMemberRole: String {
    case admin
    case supervisor
    case member

    var label: String {
        switch self {
        case .admin: "Admin"
        case .supervisor: "Supervisor"
        case .member: "Member"
        }
    }
}

struct ClubMember: Identifiable {
    let id = UUID()
    let name: String
    let role: ClubMemberRole
}

// MARK: - Club Detail View

struct ClubDetailView: View {
    let club: ClubItem
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ClubDetailTab = .posts
    @State private var isJoined: Bool
    @State private var dominantColor: Color?
    @State private var isDescriptionExpanded = false
    @State private var showHeaderBar = false
    @State private var showComposeSheet = false
    @State private var showInviteSheet = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var isMuted = false
    @State private var detailVM: ClubDetailViewModel?
    @FocusState private var isSearchFocused: Bool

    init(club: ClubItem) {
        self.club = club
        self._isJoined = State(initialValue: club.isJoined)
        if let dbId = club.dbId {
            self._detailVM = State(initialValue: ClubDetailViewModel(clubId: dbId))
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    contentCard
                }
            }
            .ignoresSafeArea(edges: .top)
            .modifier(ClubDetailSoftScrollEdge())

            headerBar

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    composeFAB
                        .padding(.trailing, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .background(Color.nook.clubDetailBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .task {
            await detailVM?.loadClub()
            if let vm = detailVM {
                isJoined = vm.isMember
            }
        }
        .sheet(isPresented: $showComposeSheet) {
            ComposePostView(clubName: club.name, clubId: club.dbId)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.clubDetailBackground)
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteMemberView(clubName: club.name)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.clubDetailBackground)
        }
    }

    private var overscrollColor: Color {
        dominantColor ?? club.bannerColor
    }
}

// MARK: - Hero Section

private extension ClubDetailView {
    var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            club.bannerColor
                .frame(maxWidth: .infinity)
                .frame(height: 192)

            clubAvatar
                .offset(y: 44)
        }
        .zIndex(1)
    }

    var clubAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.nook.clubDetailAvatarBorder)
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.1), radius: 6, y: 4)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(club.bannerColor)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                )
        }
        .padding(.leading, 16)
    }
}

// MARK: - Floating Header Bar

private extension ClubDetailView {
    @ViewBuilder
    var headerBar: some View {
        if isSearchActive {
            expandedSearchBar
        } else {
            collapsedHeaderBar
        }
    }

    var collapsedHeaderBar: some View {
        HStack(spacing: 12) {
            navButton(icon: "caret-left-bold") { dismiss() }

            if showHeaderBar {
                Text(club.name)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Spacer()

            HStack(spacing: 8) {
                navButton(icon: "magnifying-glass-bold") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isSearchActive = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isSearchFocused = true
                    }
                }

                moreMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(
            Group {
                if showHeaderBar {
                    if #available(iOS 26, *) {
                        Color.nook.clubDetailBackground.opacity(0.8)
                            .background(.ultraThinMaterial)
                    } else {
                        Color.nook.clubDetailBackground
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .shadow(color: showHeaderBar ? .black.opacity(0.06) : .clear, radius: 8, y: 4)
        )
        .animation(.easeOut(duration: 0.2), value: showHeaderBar)
    }

    var expandedSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                Image("magnifying-glass-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)

                TextField(
                    "Search posts",
                    text: $searchText,
                    prompt: Text("Search posts")
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.searchBarPlaceholder)
                )
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.searchBarText)
                .focused($isSearchFocused)
            }
            .padding(.horizontal, 18)
            .frame(height: 40)
            .modifier(ClubDetailSearchBarBackground())

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    searchText = ""
                    isSearchActive = false
                    isSearchFocused = false
                }
            } label: {
                searchDismissButton
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(
            Group {
                if showHeaderBar {
                    if #available(iOS 26, *) {
                        Color.nook.clubDetailBackground.opacity(0.8)
                            .background(.ultraThinMaterial)
                    } else {
                        Color.nook.clubDetailBackground
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .shadow(color: showHeaderBar ? .black.opacity(0.06) : .clear, radius: 8, y: 4)
        )
    }

    @ViewBuilder
    var searchDismissButton: some View {
        if #available(iOS 26, *) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.nook.clubDetailTitle)
                .frame(width: 36, height: 36)
                .background(.white, in: Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Circle()
                .fill(Color.nook.searchBarBackground)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.nook.clubDetailTitle)
                }
        }
    }

    // MARK: - More Menu

    var moreMenu: some View {
        Menu {
            Button {
                // TODO: Share club
            } label: {
                Label("Share Club", image: "export")
            }

            Button {
                isMuted.toggle()
            } label: {
                Label(
                    isMuted ? "Unmute Notifications" : "Mute Notifications",
                    image: isMuted ? "bell-fill" : "bell-simple-slash"
                )
            }

            Divider()

            Button(role: .destructive) {
                // TODO: Report club
            } label: {
                Label("Report Club", image: "warning-red")
            }

            if isJoined {
                Button(role: .destructive) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isJoined = false
                    }
                } label: {
                    Label("Leave Club", image: "sign-out-red")
                }
            }
        } label: {
            navButtonLabel(icon: "dots-three-bold")
        }
        .tint(Color.nook.clubDetailTitle)
    }

    @ViewBuilder
    func navButton(icon: String, action: @escaping () -> Void) -> some View {
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
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .frame(width: 40, height: 40)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    func navButtonLabel(icon: String) -> some View {
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
                .foregroundStyle(Color.nook.clubDetailTitle)
                .frame(width: 40, height: 40)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        }
    }
}

// MARK: - Search Bar Background

private struct ClubDetailSearchBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(.white, in: Capsule())
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(Color.nook.searchBarBackground)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Compose FAB

private extension ClubDetailView {
    @ViewBuilder
    var composeFAB: some View {
        if #available(iOS 26, *) {
            Button {
                showComposeSheet = true
            } label: {
                Image("chat-circle-text-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Button {
                showComposeSheet = true
            } label: {
                Image("chat-circle-text-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.nook.clubDetailJoinedButton, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 7.5, y: 5)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: -2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Content Card

private extension ClubDetailView {
    var contentCard: some View {
        VStack(spacing: 0) {
            clubInfo
                .padding(.top, 56)
                .padding(.horizontal, 16)

            clubDescription
                .padding(.top, 12)
                .padding(.horizontal, 16)

            tabBar
                .padding(.top, 20)

            tabContent
        }
        .background(Color.nook.clubDetailBackground)
    }
}

// MARK: - Club Info (name, members, join)

private extension ClubDetailView {
    var clubInfo: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(NookFont.outfitHeadingMedium)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .onGeometryChange(for: Bool.self) { proxy in
                        proxy.frame(in: .global).maxY < 0
                    } action: { scrolledPast in
                        showHeaderBar = scrolledPast
                    }

                Text(club.memberCount)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }

            Spacer()

            joinButton
        }
    }

    var joinButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()

            Task {
                if isJoined {
                    await detailVM?.leaveClub()
                } else {
                    await detailVM?.joinClub()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isJoined = detailVM?.isMember ?? !isJoined
                }
            }
        } label: {
            HStack(spacing: 4) {
                if isJoined {
                    Image("check-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }

                Text(isJoined ? "Joined" : "Join")
                    .font(NookFont.labelBoldSmall)
            }
            .foregroundStyle(isJoined ? .white : Color.nook.clubDetailTitle)
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(isJoined ? Color.nook.clubDetailJoinedButton : .clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isJoined ? Color.clear : Color.nook.detailTabBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Club Description

private extension ClubDetailView {
    var clubDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(club.description)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)
                .lineSpacing(5)
                .lineLimit(isDescriptionExpanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isDescriptionExpanded {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isDescriptionExpanded = true
                    }
                } label: {
                    Text("Read more")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Tab Bar

private extension ClubDetailView {
    var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClubDetailTab.allCases) { tab in
                    tabChip(tab)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    func tabChip(_ tab: ClubDetailTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.label)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(isSelected ? .white : Color.nook.clubDetailTitle)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.nook.clubDetailJoinedButton : .clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : Color.nook.detailTabBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Content

private extension ClubDetailView {
    @ViewBuilder
    var tabContent: some View {
        switch selectedTab {
        case .posts:
            postsTab
        case .polls:
            pollsTab
        case .mentions:
            mentionsTab
        case .members:
            membersTab
        }
    }

    func placeholderTab(_ text: String) -> some View {
        Text(text)
            .font(NookFont.label)
            .foregroundStyle(Color.nook.clubDetailMeta)
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(24)
            .padding(.bottom, 100)
    }
}

// MARK: - Posts Tab

private extension ClubDetailView {
    var filteredPosts: [ClubPost] {
        if searchText.isEmpty { return Self.mockPosts }
        return Self.mockPosts.filter {
            $0.body.localizedCaseInsensitiveContains(searchText) ||
            $0.authorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var postsTab: some View {
        VStack(spacing: 16) {
            if !isSearchActive {
                composeBar
                    .padding(.top, 16)

                if let pinned = Self.mockPinnedDiscussion {
                    pinnedCard(pinned)
                }
            }

            ForEach(filteredPosts) { post in
                NavigationLink(value: post) {
                    postCard(post)
                }
                .buttonStyle(.plain)
            }

            if isSearchActive && filteredPosts.isEmpty {
                Text("No posts match \"\(searchText)\"")
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isSearchActive ? 16 : 0)
        .padding(.bottom, 100)
    }
}

// MARK: - Compose Bar

private extension ClubDetailView {
    var composeBar: some View {
        Button {
            showComposeSheet = true
        } label: {
            composeBarContent
        }
        .buttonStyle(.plain)
    }

    var composeBarContent: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.nook.secondary)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

            Text("Share something with the club...")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.clubDetailMeta)

            Spacer()

            Image("image")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.clubDetailTitle)
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                .fill(Color.nook.clubDetailComposeCard)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                        .strokeBorder(Color.nook.clubDetailComposeBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }
}

// MARK: - Pinned Discussion Card

private extension ClubDetailView {
    func pinnedCard(_ pinned: PinnedDiscussion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pinned header
            HStack(spacing: 6) {
                Image("push-pin-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.nook.clubDetailPinned)

                Text("PINNED DISCUSSION")
                    .font(NookFont.captionBold)
                    .tracking(0.3)
                    .foregroundStyle(Color.nook.clubDetailPinned)
            }
            .padding(.top, 17)
            .padding(.horizontal, 17)

            // Title
            Text(pinned.title)
                .font(NookFont.outfitLabelBold)
                .foregroundStyle(Color.nook.clubDetailTitle)
                .padding(.top, 12)
                .padding(.horizontal, 17)

            // Description
            Text(pinned.description)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.clubDetailMeta)
                .lineLimit(2)
                .lineSpacing(3)
                .padding(.top, 6)
                .padding(.horizontal, 17)

            // Footer
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.nook.clubDetailMeta)

                    Text(pinned.commentCount)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.nook.clubDetailMeta)

                    Text(pinned.timeAgo)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 17)
            .padding(.bottom, 17)
        }
        .background(
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.clubDetailPostCard)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                        .strokeBorder(Color.nook.clubDetailPostCardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }
}

// MARK: - Post Card

private extension ClubDetailView {
    func postCard(_ post: ClubPost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + name + time
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.nook.mutedForeground)
                    )

                HStack(spacing: 6) {
                    Text(post.authorName)
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    Text(post.timeAgo)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }

                Spacer()
            }
            .padding(.top, 17)
            .padding(.horizontal, 17)

            // Post body
            postBodyText(post)
                .padding(.top, 12)
                .padding(.horizontal, 17)

            // Poll (optional)
            if let poll = post.poll {
                pollView(poll)
                    .padding(.top, 12)
                    .padding(.horizontal, 17)
            }

            // Post image (optional)
            if post.imageName != nil || post.placeholderColor != nil {
                postImage(post)
                    .padding(.top, 12)
                    .padding(.horizontal, 17)
            }

            // Footer: like + comment + share
            postFooter(post)
                .padding(.top, 12)
                .padding(.horizontal, 17)
                .padding(.bottom, 17)
        }
        .background(
            RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                .fill(Color.nook.clubDetailPostCard)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous)
                        .strokeBorder(Color.nook.clubDetailPostCardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    func postBodyText(_ post: ClubPost) -> some View {
        Group {
            if post.boldRanges.isEmpty {
                Text(post.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineSpacing(5)
            } else {
                styledPostText(post.body, boldRanges: post.boldRanges)
                    .lineSpacing(5)
            }
        }
    }

    func styledPostText(_ text: String, boldRanges: [String]) -> Text {
        var result = Text("")
        var remaining = text

        for boldText in boldRanges {
            if let range = remaining.range(of: boldText) {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    result = result + Text(before)
                        .font(NookFont.labelMediumSmall)
                        .foregroundColor(Color.nook.clubDetailTitle)
                }
                result = result + Text(boldText)
                    .font(NookFont.labelBoldSmall)
                    .foregroundColor(Color.nook.clubDetailJoinedButton)
                remaining = String(remaining[range.upperBound...])
            }
        }

        if !remaining.isEmpty {
            result = result + Text(remaining)
                .font(NookFont.labelMediumSmall)
                .foregroundColor(Color.nook.clubDetailTitle)
        }

        return result
    }

    func postImage(_ post: ClubPost) -> some View {
        Group {
            if let color = post.placeholderColor {
                color
            } else if let imageName = post.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 189)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
    }

    func postFooter(_ post: ClubPost) -> some View {
        HStack(spacing: 0) {
            // Like
            HStack(spacing: 6) {
                Image("heart")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text(post.likes)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }

            Spacer()
                .frame(width: 16)

            // Comment
            HStack(spacing: 6) {
                Image("chat-circle")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text(post.comments)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }

            Spacer()

            // Share
            Image("share-network")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.clubDetailMeta)
        }
    }

    func pollView(_ poll: PostPoll) -> some View {
        VStack(spacing: 8) {
            ForEach(poll.options) { option in
                pollOptionRow(option, totalVotes: poll.totalVotes)
            }

            HStack {
                Text("\(poll.totalVotes) votes")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text("·")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text(poll.duration)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
    }

    func pollOptionRow(_ option: PollOption, totalVotes: Int) -> some View {
        let percentage = totalVotes > 0 ? Double(option.votes) / Double(totalVotes) : 0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.nook.clubDetailPollBar)

                // Fill bar
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.nook.clubDetailPollBarFill)
                    .frame(width: max(geo.size.width * percentage, 0))

                // Label + percentage
                HStack {
                    Text(option.text)
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    Spacer()

                    Text("\(Int(percentage * 100))%")
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
                .padding(.horizontal, 14)
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Polls Tab

private extension ClubDetailView {
    var pollsTab: some View {
        let pollPosts = Self.mockPollPosts
        return VStack(spacing: 16) {
            if pollPosts.isEmpty {
                Text("No polls yet")
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ForEach(pollPosts) { post in
                    NavigationLink(value: post) {
                        postCard(post)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 100)
    }
}

// MARK: - Mentions Tab

private extension ClubDetailView {
    var mentionsTab: some View {
        VStack(spacing: 16) {
            ForEach(Self.mockMentionPosts) { post in
                NavigationLink(value: post) {
                    postCard(post)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 100)
    }
}

// MARK: - Members Tab

private extension ClubDetailView {
    var membersTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(club.memberCount)")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Spacer()

                Button {
                    showInviteSheet = true
                } label: {
                    Text("Invite People")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(Color.nook.clubDetailJoinedButton)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            ForEach(Self.mockMembers) { member in
                memberRow(member)
            }
        }
        .padding(.bottom, 100)
    }

    func memberRow(_ member: ClubMember) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.nook.secondary)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

            Text(member.name)
                .font(NookFont.labelSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Spacer()

            Text(member.role.label)
                .font(NookFont.captionSemiBold)
                .foregroundStyle(Color.nook.clubDetailMeta)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Scroll Edge

private struct ClubDetailSoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Mock Data

extension ClubDetailView {
    static let mockMentionPosts: [ClubPost] = [
        ClubPost(
            authorName: "Sophia Chen",
            timeAgo: "3h",
            body: "Shoutout to @You for recommending The Cloud Weaver last month. Best rec I've gotten in this club.",
            boldRanges: ["@You"],
            likes: "45",
            comments: "8"
        ),
        ClubPost(
            authorName: "Kai Tanaka",
            timeAgo: "1d",
            body: "Hey @You have you caught up with the latest episode? The sky kingdom reveal was insane. We need to talk about it.",
            boldRanges: ["@You"],
            likes: "23",
            comments: "12"
        ),
        ClubPost(
            authorName: "Liam Brooks",
            timeAgo: "2d",
            body: "Adding @You to the group watch thread since you said you were interested last week. Don't miss it!",
            boldRanges: ["@You"],
            likes: "16",
            comments: "4"
        ),
    ]

    static let mockPinnedDiscussion: PinnedDiscussion? = PinnedDiscussion(
        title: "Winter 2024 Megathread",
        description: "What is everyone watching this season? Drop your early impressions, theories, and hidden gems below.",
        commentCount: "342 Comments",
        timeAgo: "2 days ago"
    )

    static let mockMembers: [ClubMember] = [
        ClubMember(name: "Kai Tanaka", role: .admin),
        ClubMember(name: "Elena Vance", role: .supervisor),
        ClubMember(name: "Riku Ota", role: .supervisor),
        ClubMember(name: "Maya Lin", role: .member),
        ClubMember(name: "Sophia Chen", role: .member),
        ClubMember(name: "Liam Brooks", role: .member),
        ClubMember(name: "Nadia Petrova", role: .member),
        ClubMember(name: "Jin Park", role: .member),
        ClubMember(name: "Ava Kim", role: .member),
    ]

    static let mockPosts: [ClubPost] = [
        ClubPost(
            authorName: "Maya Lin",
            timeAgo: "2h",
            body: "Just finished episode 12 of The Cloud Weaver and I'm completely blown away. The art direction in the sky kingdom scenes is some of the best I've seen in years. Does anyone know if the manga covers past this arc?",
            boldRanges: ["The Cloud Weaver"],
            imageName: "mock-club-post-1",
            placeholderColor: Color(hex: 0x87CEEB).opacity(0.6),
            likes: "1.2k",
            comments: "84"
        ),
        ClubPost(
            authorName: "Kai Tanaka",
            timeAgo: "5h",
            body: "What's the best anime of the season so far? Cast your vote!",
            likes: "342",
            comments: "56",
            poll: PostPoll(
                options: [
                    PollOption(text: "The Cloud Weaver", votes: 156),
                    PollOption(text: "Starfall Chronicles", votes: 89),
                    PollOption(text: "Iron Bloom", votes: 62),
                    PollOption(text: "Echoes of Silence", votes: 35),
                ],
                totalVotes: 342,
                duration: "2 days left"
            )
        ),
    ]

    static let mockPollPosts: [ClubPost] = [
        ClubPost(
            authorName: "Kai Tanaka",
            timeAgo: "5h",
            body: "What's the best anime of the season so far? Cast your vote!",
            likes: "342",
            comments: "56",
            poll: PostPoll(
                options: [
                    PollOption(text: "The Cloud Weaver", votes: 156),
                    PollOption(text: "Starfall Chronicles", votes: 89),
                    PollOption(text: "Iron Bloom", votes: 62),
                    PollOption(text: "Echoes of Silence", votes: 35),
                ],
                totalVotes: 342,
                duration: "2 days left"
            )
        ),
        ClubPost(
            authorName: "Elena Vance",
            timeAgo: "1d",
            body: "Next group watch — which day works best for everyone?",
            likes: "128",
            comments: "23",
            poll: PostPoll(
                options: [
                    PollOption(text: "Friday evening", votes: 45),
                    PollOption(text: "Saturday afternoon", votes: 67),
                    PollOption(text: "Sunday evening", votes: 16),
                ],
                totalVotes: 128,
                duration: "Ended"
            )
        ),
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClubDetailView(
            club: ClubItem(
                name: "Anime Corner",
                memberCount: "24.5k Members",
                description: "The ultimate spot for seasonal discussions, recommendation threads, and sharing your favorite setups. Keep it cozy and respectful.",
                category: .anime,
                bannerColor: Color(hex: 0xBA68C8).opacity(0.3),
                isJoined: true
            )
        )
    }
}
