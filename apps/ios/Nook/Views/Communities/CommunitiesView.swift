import SwiftUI

// MARK: - Club Category

enum ClubCategory: CaseIterable, Identifiable {
    case movies
    case tvShows
    case anime
    case manga
    case books
    case games

    var id: String {
        switch self {
        case .movies: "movies"
        case .tvShows: "tvShows"
        case .anime: "anime"
        case .manga: "manga"
        case .books: "books"
        case .games: "games"
        }
    }

    var label: String {
        switch self {
        case .movies: "Movies"
        case .tvShows: "TV Shows"
        case .anime: "Anime"
        case .manga: "Manga"
        case .books: "Books"
        case .games: "Games"
        }
    }

    var dotColor: Color {
        switch self {
        case .movies: Color.nook.badgeMovieText
        case .tvShows: Color.nook.badgeTvShowText
        case .anime: Color.nook.badgeAnimeText
        case .manga: Color.nook.badgeMangaText
        case .books: Color.nook.badgeBookText
        case .games: Color.nook.badgeGameText
        }
    }

    var iconName: String {
        switch self {
        case .movies: "reel"
        case .tvShows: "videocamera-record"
        case .anime: "star-fall"
        case .manga: "notes"
        case .books: "book"
        case .games: "gamepad"
        }
    }

    var iconColor: Color {
        switch self {
        case .movies: Color(hex: 0x968A79)
        case .tvShows: Color(hex: 0x7896B2)
        case .anime: Color(hex: 0xB68B9F)
        case .manga: Color(hex: 0x7C9E7B)
        case .books: Color(hex: 0x968A79)
        case .games: Color(hex: 0xB58572)
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .movies: Color(hex: 0xE8E2D9, alpha: 0.4)
        case .tvShows: Color(hex: 0xD4DFE8, alpha: 0.3)
        case .anime: Color(hex: 0xEAD6DF, alpha: 0.3)
        case .manga: Color(hex: 0xD3E1D2, alpha: 0.3)
        case .books: Color(hex: 0xE8E2D9, alpha: 0.4)
        case .games: Color(hex: 0xE4C7BA, alpha: 0.3)
        }
    }

    static func from(dbValue: String) -> ClubCategory {
        switch dbValue {
        case "movies": .movies
        case "tv", "tvShows": .tvShows
        case "anime": .anime
        case "manga": .manga
        case "books": .books
        case "games": .games
        default: .movies
        }
    }
}

// MARK: - Club Model

struct ClubItem: Identifiable, Hashable {
    let id = UUID()
    let dbId: UUID?
    let name: String
    let memberCount: String
    let description: String
    let category: ClubCategory
    let bannerColor: Color
    let bannerURL: URL?
    let themeHex: UInt?
    var isJoined: Bool

    static func == (lhs: ClubItem, rhs: ClubItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Solid accent used for buttons, tabs and other primary surfaces.
    var accentColor: Color {
        ClubItem.color(fromHex: themeHex) ?? Color.nook.clubDetailJoinedButton
    }

    /// Parse a stored 6-digit hex string (e.g. "BA68C8") into a UInt.
    static func parseHex(_ string: String?) -> UInt? {
        guard let string, let value = UInt(string.replacingOccurrences(of: "#", with: ""), radix: 16) else { return nil }
        return value
    }

    static func color(fromHex hex: UInt?) -> Color? {
        hex.map { Color(hex: $0) }
    }

    init(
        name: String,
        memberCount: String,
        description: String,
        category: ClubCategory,
        bannerColor: Color,
        bannerURL: URL? = nil,
        themeHex: UInt? = nil,
        isJoined: Bool = false,
        dbId: UUID? = nil
    ) {
        self.name = name
        self.memberCount = memberCount
        self.description = description
        self.category = category
        self.bannerColor = bannerColor
        self.bannerURL = bannerURL
        self.themeHex = themeHex
        self.isJoined = isJoined
        self.dbId = dbId
    }

    init(from row: ClubRow, isJoined: Bool) {
        self.dbId = row.id
        self.name = row.name
        self.memberCount = "\(row.memberCount) Members"
        self.description = row.description ?? ""
        self.category = ClubCategory.from(dbValue: row.category)
        self.themeHex = ClubItem.parseHex(row.themeColor)
        let theme = ClubItem.color(fromHex: ClubItem.parseHex(row.themeColor))
        self.bannerColor = (theme ?? ClubCategory.from(dbValue: row.category).dotColor).opacity(0.3)
        self.bannerURL = row.bannerUrl.flatMap { URL(string: $0) }
        self.isJoined = isJoined
    }
}

// MARK: - Clubs View

struct ClubsView: View {
    @State private var viewModel = CommunitiesViewModel()
    @State private var showMyClubs = false
    @State private var selectedCategory: ClubCategory? = nil
    @State private var isSearchActive = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var clubs: [ClubItem] {
        let myClubIds = Set(viewModel.myClubs.map { $0.id })
        let allRows: [ClubRow] = showMyClubs ? viewModel.myClubs : viewModel.publicClubs
        return allRows.map { ClubItem(from: $0, isJoined: myClubIds.contains($0.id)) }
    }

    private var filteredClubs: [ClubItem] {
        var results = clubs

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return results
    }

    var body: some View {
        scrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.nook.searchBackground)
            .modifier(
                ClubsTopBar(
                    isSearchActive: $isSearchActive,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused
                )
            )
            .task {
                await viewModel.loadClubs()
            }
            .refreshable {
                await viewModel.loadClubs()
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                filterChips

                LazyVStack(spacing: 20) {
                    ForEach(filteredClubs) { club in
                        NavigationLink(value: club) {
                            ClubCard(club: club) {
                                toggleJoined(club)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .padding(.bottom, 100)
        }
        .modifier(ClubsSoftScrollEdge())
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Discover / My Clubs toggle
                scopeChip(label: "Discover", isSelected: !showMyClubs) {
                    showMyClubs = false
                }

                scopeChip(label: "My Clubs", isSelected: showMyClubs) {
                    showMyClubs = true
                }

                // Divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.nook.searchFilterBorder)
                    .frame(width: 2, height: 20)
                    .padding(.horizontal, 4)

                // Category chips
                ForEach(ClubCategory.allCases) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func scopeChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { action() }
            } label: {
                Text(label)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .padding(.horizontal, 20)
                    .frame(height: 38)
                    .background(
                        isSelected ? Color.nook.searchFilterSelected : .white,
                        in: Capsule()
                    )
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { action() }
            } label: {
                Text(label)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(isSelected ? .white : Color.nook.searchFilterText)
                    .padding(.horizontal, 20)
                    .frame(height: 38)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.nook.searchFilterSelected : Color.white)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? Color.clear : Color.nook.searchFilterBorder,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func categoryChip(_ category: ClubCategory) -> some View {
        let isSelected = selectedCategory == category

        if #available(iOS 26, *) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedCategory = isSelected ? nil : category
                }
            } label: {
                HStack(spacing: 6) {
                    if !isSelected {
                        Circle()
                            .fill(category.dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(category.label)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .padding(.horizontal, 20)
                .frame(height: 38)
                .background(
                    isSelected ? Color.nook.searchFilterSelected : .white,
                    in: Capsule()
                )
                .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedCategory = isSelected ? nil : category
                }
            } label: {
                HStack(spacing: 6) {
                    if !isSelected {
                        Circle()
                            .fill(category.dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(category.label)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isSelected ? .white : Color.nook.searchFilterText)
                }
                .padding(.horizontal, 20)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.nook.searchFilterSelected : Color.white)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                                isSelected ? Color.clear : Color.nook.searchFilterBorder,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func toggleJoined(_ club: ClubItem) {
        guard let dbId = club.dbId else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        Task {
            if club.isJoined {
                await viewModel.leaveClub(clubId: dbId)
            } else {
                await viewModel.joinClub(clubId: dbId)
            }
        }
    }
}

// MARK: - Top Bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct ClubsTopBar: ViewModifier {
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                topBarContent
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                topBarContent
                    .background(Color.nook.searchBackground)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var topBarContent: some View {
        if isSearchActive {
            expandedSearchBar
        } else {
            collapsedHeader
        }
    }

    // MARK: - Collapsed Header (Title + Search button)

    private var collapsedHeader: some View {
        HStack(alignment: .center) {
            Text("Clubs")
                .font(NookFont.headingMediumBold)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()

            searchButton
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var searchButton: some View {
        if #available(iOS 26, *) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused.wrappedValue = true
                }
            } label: {
                Image("magnifying-glass-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 40, height: 40)
                    .background(.white, in: Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused.wrappedValue = true
                }
            } label: {
                Image("magnifying-glass-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 40, height: 40)
                    .background(Color.nook.searchBarBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Expanded Search Bar

    private var expandedSearchBar: some View {
        HStack(spacing: 10) {
            searchField
            dismissButton
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            TextField(
                "Search clubs",
                text: $searchText,
                prompt: Text("Search clubs")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)
            .focused(isSearchFocused)
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
        .modifier(ClubsSearchBarBackground())
    }

    @ViewBuilder
    private var dismissButton: some View {
        if #available(iOS 26, *) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    searchText = ""
                    isSearchActive = false
                    isSearchFocused.wrappedValue = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    searchText = ""
                    isSearchActive = false
                    isSearchFocused.wrappedValue = false
                }
            } label: {
                Circle()
                    .fill(Color.nook.searchBarBackground)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.nook.sectionTitle)
                    }
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }
}

// MARK: - Search bar background (glass on iOS 26, solid fallback)

private struct ClubsSearchBarBackground: ViewModifier {
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

// MARK: - Scroll edge blur (iOS 26+)

private struct ClubsSoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Club Card

private struct ClubCard: View {
    let club: ClubItem
    let onToggleJoined: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            Group {
                if let url = club.bannerURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            club.bannerColor
                        }
                    }
                } else {
                    club.bannerColor
                }
            }
            .frame(height: 120)
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title + Join button
                HStack(alignment: .center) {
                    Text(club.name)
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.cardTitle)
                        .lineLimit(1)

                    Spacer()

                    joinButton
                }

                // Member count
                HStack(spacing: 4) {
                    Image("users-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text(club.memberCount)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }

                // Description
                Text(club.description)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.cardSubtitle)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .background(Color.nook.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    // MARK: - Join Button (non-liquid glass, kept as-is)

    private var joinButton: some View {
        Button(action: onToggleJoined) {
            HStack(spacing: 4) {
                if club.isJoined {
                    Image("check-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }

                Text(club.isJoined ? "Joined" : "Join")
                    .font(NookFont.labelBoldSmall)
            }
            .foregroundStyle(club.isJoined ? .white : Color.nook.searchFilterText)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(club.isJoined ? Color.nook.searchAddedButton : Color.nook.card)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        club.isJoined ? Color.clear : Color.nook.searchFilterBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mock Data

extension ClubsView {
    static let mockClubs: [ClubItem] = [
        ClubItem(
            name: "Anime Corner",
            memberCount: "24.5k Members",
            description: "The ultimate spot for seasonal discussions, recommendation threads, and sharing your",
            category: .anime,
            bannerColor: Color(hex: 0xBA68C8).opacity(0.3)
        ),
        ClubItem(
            name: "Cozy Book Club",
            memberCount: "12.1k Members",
            description: "Monthly reads, candle-lit aesthetics, and warm discussions about your favorite literary",
            category: .books,
            bannerColor: Color(hex: 0xD4A373).opacity(0.3),
            isJoined: true
        ),
        ClubItem(
            name: "Film Lovers",
            memberCount: "45.8k Members",
            description: "From blockbuster hits to indie gems. Review swap and nightly watch-party threads.",
            category: .movies,
            bannerColor: Color(hex: 0xE57373).opacity(0.3)
        ),
    ]
}

// MARK: - Preview

#Preview {
    ClubsView()
}
