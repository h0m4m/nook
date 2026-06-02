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
    let id: UUID
    let dbId: UUID?
    let clubId: UUID?
    let userId: UUID?
    let authorName: String
    let authorAvatarURL: URL?
    let timeAgo: String
    let body: String
    let boldRanges: [String]
    let imageName: String?
    let placeholderColor: Color?
    let imageURLs: [URL]
    let likes: String
    let comments: String
    let likesCount: Int
    let isLiked: Bool
    let isPinned: Bool
    let poll: PostPoll?
    let pollModel: ClubPollModel?
    let themeHex: UInt?

    /// The club accent color carried into the post detail.
    var accentColor: Color {
        ClubItem.color(fromHex: themeHex) ?? Color.nook.clubDetailJoinedButton
    }

    static func == (lhs: ClubPost, rhs: ClubPost) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(
        authorName: String,
        timeAgo: String,
        body: String,
        boldRanges: [String] = [],
        imageName: String? = nil,
        placeholderColor: Color? = nil,
        imageURLs: [URL] = [],
        likes: String = "0",
        comments: String = "0",
        likesCount: Int = 0,
        isLiked: Bool = false,
        isPinned: Bool = false,
        poll: PostPoll? = nil,
        pollModel: ClubPollModel? = nil,
        themeHex: UInt? = nil,
        dbId: UUID? = nil,
        clubId: UUID? = nil,
        userId: UUID? = nil,
        authorAvatarURL: URL? = nil
    ) {
        self.id = UUID()
        self.authorName = authorName
        self.timeAgo = timeAgo
        self.body = body
        self.boldRanges = boldRanges
        self.imageName = imageName
        self.placeholderColor = placeholderColor
        self.imageURLs = imageURLs
        self.likes = likes
        self.comments = comments
        self.likesCount = likesCount
        self.isLiked = isLiked
        self.isPinned = isPinned
        self.poll = poll
        self.pollModel = pollModel
        self.themeHex = themeHex
        self.dbId = dbId
        self.clubId = clubId
        self.userId = userId
        self.authorAvatarURL = authorAvatarURL
    }

    /// Build a display post from a real `ClubPostModel`.
    init(from model: ClubPostModel, isLiked: Bool, themeHex: UInt? = nil) {
        self.id = model.id
        self.dbId = model.id
        self.clubId = model.clubId
        self.userId = model.userId
        self.authorName = model.authorName
        self.authorAvatarURL = model.authorAvatarURL
        self.timeAgo = model.createdAt.clubRelativeShort
        self.body = model.body
        self.boldRanges = []
        self.imageName = nil
        self.placeholderColor = nil
        self.imageURLs = model.imageURLs
        self.likesCount = model.likesCount
        self.likes = ClubPost.formatCount(model.likesCount)
        self.comments = ClubPost.formatCount(model.commentsCount)
        self.isLiked = isLiked
        self.isPinned = model.isPinned
        self.poll = nil
        self.pollModel = model.poll
        self.themeHex = themeHex
    }

    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1_000) }
        return "\(count)"
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
    @State private var showReportConfirmation = false
    @State private var descFullHeight: CGFloat = 0
    @State private var descClampedHeight: CGFloat = 0
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

            if isMemberNow {
                composeFAB
                    .padding(.trailing, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
                isMuted = vm.isMuted
            }
        }
        .sheet(isPresented: $showComposeSheet, onDismiss: {
            Task { await detailVM?.loadPosts(page: 1) }
        }) {
            ComposePostView(clubName: club.name, clubId: club.dbId, accent: accent)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.clubDetailBackground)
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteMemberView(clubName: club.name, clubId: club.dbId, existingMemberIds: Set((detailVM?.members ?? []).map { $0.userId }))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.clubDetailBackground)
        }
        .alert("Report received", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for keeping the community safe. Our team will review this club.")
        }
    }

    private var overscrollColor: Color {
        dominantColor ?? club.bannerColor
    }

    /// Club accent — the chosen theme color, used for primary buttons/tabs.
    var accent: Color {
        detailVM?.accentColor ?? club.accentColor
    }

    /// Whether the current user is a member (gates posting/composing).
    var isMemberNow: Bool {
        detailVM?.isMember ?? isJoined
    }
}

// MARK: - Hero Section

private extension ClubDetailView {
    var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = club.bannerURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: club.bannerColor
                        }
                    }
                } else {
                    club.bannerColor
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 192)
            .clipped()

            clubAvatar
                .offset(y: 44)
        }
        .zIndex(1)
    }

    var iconURL: URL? {
        detailVM?.club?.iconUrl.flatMap { URL(string: $0) }
    }

    var clubAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.nook.clubDetailAvatarBorder)
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.1), radius: 6, y: 4)

            Group {
                if let iconURL {
                    AsyncImage(url: iconURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: avatarFallback
                        }
                    }
                } else {
                    avatarFallback
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.leading, 16)
    }

    var avatarFallback: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(club.bannerColor)
            .overlay(
                Image(systemName: "person.3.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
            )
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
            ShareLink(item: shareURL) {
                Label("Share Club", image: "export")
            }

            Button {
                isMuted.toggle()
                detailVM?.toggleMute()
            } label: {
                Label(
                    isMuted ? "Unmute Notifications" : "Mute Notifications",
                    image: isMuted ? "bell-fill" : "bell-simple-slash"
                )
            }

            Divider()

            Button(role: .destructive) {
                detailVM?.reportClub(reason: nil)
                showReportConfirmation = true
            } label: {
                Label("Report Club", image: "warning-red")
            }

            if isJoined {
                Button(role: .destructive) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    Task {
                        await detailVM?.leaveClub()
                        withAnimation(.easeOut(duration: 0.2)) {
                            isJoined = detailVM?.isMember ?? false
                        }
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

    var shareURL: URL {
        if let dbId = club.dbId {
            return URL(string: "https://nook.app/club/\(dbId.uuidString)") ?? URL(string: "https://nook.app")!
        }
        return URL(string: "https://nook.app")!
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
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(accent, in: Circle())
                    .contentShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
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
                    .frame(width: 60, height: 60)
                    .background(accent, in: Circle())
                    .contentShape(Circle())
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

                Text(memberCountText)
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
                    .fill(isJoined ? accent : .clear)
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
    var descriptionText: String {
        detailVM?.club?.description ?? club.description
    }

    /// True only when the (3-line clamped) description actually overflows.
    var isDescriptionTruncated: Bool {
        descFullHeight > descClampedHeight + 1
    }

    var clubDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(descriptionText)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)
                .lineSpacing(5)
                .lineLimit(isDescriptionExpanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(descriptionMeasurement)

            if !isDescriptionExpanded && isDescriptionTruncated {
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

    /// Hidden probes: measure the full vs 3-line-clamped height of the description
    /// so "Read more" only appears when the text is genuinely clipped.
    var descriptionMeasurement: some View {
        ZStack {
            Text(descriptionText)
                .font(NookFont.labelMediumSmall)
                .lineSpacing(5)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { g in
                    Color.clear.onAppear { descFullHeight = g.size.height }
                        .onChange(of: g.size.height) { _, h in descFullHeight = h }
                })

            Text(descriptionText)
                .font(NookFont.labelMediumSmall)
                .lineSpacing(5)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { g in
                    Color.clear.onAppear { descClampedHeight = g.size.height }
                        .onChange(of: g.size.height) { _, h in descClampedHeight = h }
                })
        }
        .hidden()
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
                        .fill(isSelected ? accent : .clear)
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
    /// Build a navigable display post carrying the club's accent theme.
    func displayPost(_ model: ClubPostModel) -> ClubPost {
        ClubPost(from: model, isLiked: detailVM?.isPostLiked(model.id) ?? false, themeHex: club.resolvedAccentHex)
    }

    /// Pinned post models, search-filtered (rendered as compact highlight cards).
    var pinnedModels: [ClubPostModel] {
        (detailVM?.pinnedPosts ?? []).filter { model in
            searchText.isEmpty ||
            model.body.localizedCaseInsensitiveContains(searchText) ||
            model.authorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Real feed posts (or mock data when rendered in a preview without a view model).
    var displayPosts: [ClubPost] {
        guard let vm = detailVM else { return Self.mockPosts }
        return vm.feedPosts.map { displayPost($0) }
    }

    func matchesSearch(_ post: ClubPost) -> Bool {
        searchText.isEmpty ||
        post.body.localizedCaseInsensitiveContains(searchText) ||
        post.authorName.localizedCaseInsensitiveContains(searchText)
    }

    var filteredPosts: [ClubPost] { displayPosts.filter(matchesSearch) }

    var postsTab: some View {
        VStack(spacing: 16) {
            if !isSearchActive && isMemberNow {
                composeBar
                    .padding(.top, 16)
            }

            if let vm = detailVM, vm.isLoadingPosts, vm.posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if pinnedModels.isEmpty && filteredPosts.isEmpty {
                emptyPostsState
            }

            // Pinned posts — compact highlight cards
            ForEach(pinnedModels, id: \.id) { model in
                NavigationLink(value: displayPost(model)) {
                    pinnedCard(from: model)
                }
                .buttonStyle(.plain)
                .contextMenu { pinnedContextMenu(model) }
            }

            // Regular feed
            ForEach(filteredPosts) { post in
                NavigationLink(value: post) {
                    postCard(post)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isSearchActive ? 16 : 0)
        .padding(.bottom, 100)
    }

    /// Long-press actions on a pinned card (moderators).
    @ViewBuilder
    func pinnedContextMenu(_ model: ClubPostModel) -> some View {
        if detailVM?.canModerate == true {
            Button {
                detailVM?.togglePin(postId: model.id)
            } label: {
                sizedMenuLabel("Unpin", icon: "push-pin")
            }
        }
        if detailVM?.canDeletePost(model) == true {
            Button(role: .destructive) {
                detailVM?.deletePost(postId: model.id)
            } label: {
                sizedMenuLabel("Delete Post", icon: "trash")
            }
        }
    }

    @ViewBuilder
    var emptyPostsState: some View {
        if isSearchActive {
            Text("No posts match \"\(searchText)\"")
                .font(NookFont.label)
                .foregroundStyle(Color.nook.clubDetailMeta)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 6) {
                Text("No posts yet")
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                Text("Be the first to share something with the club.")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(.horizontal, 24)
        }
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
    func pinnedCard(from post: ClubPostModel) -> some View {
        pinnedCard(
            PinnedDiscussion(
                title: post.authorName,
                description: post.body,
                commentCount: "\(post.commentsCount) Comments",
                timeAgo: post.createdAt.clubRelativeShort
            )
        )
    }

    func pinnedCard(_ pinned: PinnedDiscussion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pinned header
            HStack(spacing: 6) {
                Image("push-pin-fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
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
            // Header: avatar + name + time + menu
            HStack(spacing: 12) {
                ClubAvatarView(url: post.authorAvatarURL, size: 40)

                HStack(spacing: 6) {
                    Text(post.authorName)
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    Text(post.timeAgo)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }

                Spacer()

                postMenu(post)
            }
            .padding(.top, 17)
            .padding(.horizontal, 17)

            // Post body
            postBodyText(post)
                .padding(.top, 12)
                .padding(.horizontal, 17)

            // Poll (optional)
            if let pollModel = post.pollModel {
                ClubPollVoteView(poll: pollModel, accent: accent)
                    .padding(.top, 12)
                    .padding(.horizontal, 17)
            } else if let poll = post.poll {
                pollView(poll)
                    .padding(.top, 12)
                    .padding(.horizontal, 17)
            }

            // Post image (optional)
            if !post.imageURLs.isEmpty || post.imageName != nil || post.placeholderColor != nil {
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

    /// Per-post overflow menu: pin/unpin (moderators) and delete (author or moderator).
    @ViewBuilder
    func postMenu(_ post: ClubPost) -> some View {
        let canModerate = detailVM?.canModerate ?? false
        let canDelete = detailVM?.canDeletePost(authorId: post.userId) ?? false

        if let dbId = post.dbId, canModerate || canDelete {
            Menu {
                if canModerate {
                    Button {
                        detailVM?.togglePin(postId: dbId)
                    } label: {
                        sizedMenuLabel(post.isPinned ? "Unpin" : "Pin to club", icon: "push-pin")
                    }
                }
                if canDelete {
                    Button(role: .destructive) {
                        detailVM?.deletePost(postId: dbId)
                    } label: {
                        sizedMenuLabel("Delete Post", icon: "trash")
                    }
                }
            } label: {
                Image("dots-three-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
                    .foregroundColor(accent)
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

    @ViewBuilder
    func postImage(_ post: ClubPost) -> some View {
        if !post.imageURLs.isEmpty {
            if post.imageURLs.count == 1, let url = post.imageURLs.first {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color.nook.secondary
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 189)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.imageURLs, id: \.self) { url in
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image): image.resizable().scaledToFill()
                                default: Color.nook.secondary
                                }
                            }
                            .frame(width: 260, height: 189)
                            .clipShape(RoundedRectangle(cornerRadius: NookRadii.md, style: .continuous))
                        }
                    }
                }
            }
        } else {
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
    }

    func postFooter(_ post: ClubPost) -> some View {
        HStack(spacing: 0) {
            // Like
            Button {
                if let dbId = post.dbId {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    detailVM?.toggleLike(postId: dbId)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(post.isLiked ? "heart-fill" : "heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(post.isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)

                    Text(post.likes)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(post.isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)
                }
            }
            .buttonStyle(.plain)

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
    var pollPosts: [ClubPost] {
        guard let vm = detailVM else { return Self.mockPollPosts }
        return vm.pollPosts.map { displayPost($0) }
    }

    var pollsTab: some View {
        VStack(spacing: 16) {
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
    var mentionPosts: [ClubPost] {
        guard let vm = detailVM else { return Self.mockMentionPosts }
        return vm.visibleMentions.map { displayPost($0) }
    }

    var mentionsTab: some View {
        VStack(spacing: 16) {
            if mentionPosts.isEmpty {
                VStack(spacing: 6) {
                    Text("No mentions yet")
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)
                    Text("When someone @mentions you here, it'll show up in this tab.")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding(.horizontal, 24)
            } else {
                ForEach(mentionPosts) { post in
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
        .task {
            await detailVM?.loadMentions()
        }
    }
}

// MARK: - Members Tab

private extension ClubDetailView {
    var memberCountText: String {
        if let count = detailVM?.club?.memberCount {
            return "\(count) Members"
        }
        return club.memberCount
    }

    var membersTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text(memberCountText)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Spacer()

                // Only members can invite others.
                if isMemberNow {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Text("Invite People")
                            .font(NookFont.labelBoldSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            if let vm = detailVM {
                ForEach(vm.visibleMembers, id: \.userId) { member in
                    memberRow(member)
                }
            } else {
                ForEach(Self.mockMembers) { member in
                    mockMemberRow(member)
                }
            }
        }
        .padding(.bottom, 100)
    }

    func memberRow(_ member: ClubMemberRow) -> some View {
        let isOwnerRole = member.role == "owner"
        let isAdminRole = member.role == "owner" || member.role == "admin"

        return HStack(spacing: 12) {
            ClubAvatarView(
                url: member.userProfile?.avatarUrl.flatMap { URL(string: $0) },
                size: 40
            )

            Text(member.userProfile?.fullName ?? member.userProfile?.username ?? "Member")
                .font(NookFont.labelSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Spacer()

            Text(Self.roleLabel(member.role))
                .font(NookFont.captionSemiBold)
                .foregroundStyle(isAdminRole ? accent : Color.nook.clubDetailMeta)

            memberManagementMenu(member, isOwnerRole: isOwnerRole)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Owner/admin actions on a member row (promote/demote/remove), gated by viewer role.
    @ViewBuilder
    func memberManagementMenu(_ member: ClubMemberRow, isOwnerRole: Bool) -> some View {
        let vm = detailVM
        let viewerIsOwner = vm?.isOwner ?? false
        let viewerIsAdmin = vm?.isOwnerOrAdmin ?? false
        let isSelf = member.userId == vm?.currentUserId
        // Can't manage the owner or yourself.
        let canManage = !isOwnerRole && !isSelf && (viewerIsOwner || (viewerIsAdmin && member.role == "member"))

        if canManage {
            Menu {
                if viewerIsOwner {
                    if member.role == "admin" {
                        Button {
                            vm?.setMemberRole(userId: member.userId, role: "member")
                        } label: {
                            sizedMenuLabel("Remove Admin", icon: "star")
                        }
                    } else {
                        Button {
                            vm?.setMemberRole(userId: member.userId, role: "admin")
                        } label: {
                            sizedMenuLabel("Make Admin", icon: "star-fill")
                        }
                    }
                }
                Button(role: .destructive) {
                    vm?.removeMember(userId: member.userId)
                } label: {
                    sizedMenuLabel("Remove from Club", icon: "user-minus")
                }
            } label: {
                Image("dots-three-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    func mockMemberRow(_ member: ClubMember) -> some View {
        HStack(spacing: 12) {
            ClubAvatarView(url: nil, size: 40)

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

    static func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": "Owner"
        case "admin": "Admin"
        case "moderator", "supervisor": "Supervisor"
        default: "Member"
        }
    }
}

// MARK: - Avatar

struct ClubAvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.nook.secondary)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Color.nook.mutedForeground)
            )
    }
}

// MARK: - Poll Vote View (real, interactive)

struct ClubPollVoteView: View {
    let poll: ClubPollModel
    var accent: Color = Color.nook.clubDetailJoinedButton
    @State private var options: [ClubPollOptionModel]
    @State private var totalVotes: Int
    @State private var myVote: UUID?
    @State private var didLoadVote = false
    @State private var isVoting = false

    private let service = ClubService()

    init(poll: ClubPollModel, accent: Color = Color.nook.clubDetailJoinedButton) {
        self.poll = poll
        self.accent = accent
        self._options = State(initialValue: poll.options)
        self._totalVotes = State(initialValue: poll.totalVotes)
    }

    /// Once you've voted (or the poll closed), it's locked — results only.
    private var isLocked: Bool { myVote != nil || poll.isClosed }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    vote(for: option)
                } label: {
                    optionRow(option)
                }
                .buttonStyle(.plain)
                .disabled(isLocked || isVoting || !didLoadVote)
            }

            HStack(spacing: 4) {
                Text("\(totalVotes) \(totalVotes == 1 ? "vote" : "votes")")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text("·")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text(statusLabel)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .task {
            myVote = try? await service.getMyVote(pollId: poll.id)
            didLoadVote = true
        }
    }

    private var statusLabel: String {
        if poll.isClosed { return "Final results" }
        if myVote != nil { return "You voted · \(poll.durationLabel)" }
        return poll.durationLabel
    }

    private func optionRow(_ option: ClubPollOptionModel) -> some View {
        // Show percentages only after the user has voted or the poll closed.
        let percentage = (isLocked && totalVotes > 0) ? Double(option.votesCount) / Double(totalVotes) : 0
        let isMine = myVote == option.id

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.nook.clubDetailPollBar)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isMine ? accent.opacity(0.25) : Color.nook.clubDetailPollBarFill)
                    .frame(width: max(geo.size.width * percentage, 0))

                HStack(spacing: 6) {
                    if isMine {
                        Image("check-bold")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(accent)
                    }

                    Text(option.text)
                        .font(isMine ? NookFont.labelBoldSmall : NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    Spacer()

                    if isLocked {
                        Text("\(Int(percentage * 100))%")
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                }
                .padding(.horizontal, 14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isMine ? accent : Color.clear, lineWidth: 1.5)
            )
        }
        .frame(height: 40)
    }

    private func vote(for option: ClubPollOptionModel) {
        // Votes are final: only allow when not already voted and not closed.
        guard didLoadVote, !isLocked, !isVoting else { return }
        isVoting = true

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.easeOut(duration: 0.25)) {
            options = options.map { opt in
                let votes = opt.id == option.id ? opt.votesCount + 1 : opt.votesCount
                return ClubPollOptionModel(id: opt.id, text: opt.text, votesCount: votes)
            }
            totalVotes += 1
            myVote = option.id
        }

        Task {
            do {
                try await service.voteOnPoll(pollId: poll.id, optionId: option.id)
            } catch {
                // Revert on failure (e.g. already voted on another device).
                await MainActor.run {
                    withAnimation {
                        options = options.map { opt in
                            let votes = opt.id == option.id ? max(opt.votesCount - 1, 0) : opt.votesCount
                            return ClubPollOptionModel(id: opt.id, text: opt.text, votesCount: votes)
                        }
                        totalVotes = max(totalVotes - 1, 0)
                        myVote = nil
                    }
                }
            }
            await MainActor.run { isVoting = false }
        }
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
