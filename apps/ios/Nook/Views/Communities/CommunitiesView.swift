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
}

// MARK: - Club Model

struct ClubItem: Identifiable {
    let id = UUID()
    let name: String
    let memberCount: String
    let description: String
    let category: ClubCategory
    let bannerColor: Color
    var isJoined: Bool

    init(
        name: String,
        memberCount: String,
        description: String,
        category: ClubCategory,
        bannerColor: Color,
        isJoined: Bool = false
    ) {
        self.name = name
        self.memberCount = memberCount
        self.description = description
        self.category = category
        self.bannerColor = bannerColor
        self.isJoined = isJoined
    }
}

// MARK: - Clubs View

struct ClubsView: View {
    @State private var showMyClubs = false
    @State private var selectedCategory: ClubCategory? = nil
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var clubs: [ClubItem] = ClubsView.mockClubs
    @FocusState private var isSearchFocused: Bool

    private var filteredClubs: [ClubItem] {
        var results = clubs

        if showMyClubs {
            results = results.filter { $0.isJoined }
        }

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
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                filterChips

                LazyVStack(spacing: 20) {
                    ForEach(filteredClubs) { club in
                        ClubCard(club: club) {
                            toggleJoined(club)
                        }
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
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
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
                Text(category.label)
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
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedCategory = isSelected ? nil : category
                }
            } label: {
                Text(category.label)
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

    // MARK: - Actions

    private func toggleJoined(_ club: ClubItem) {
        guard let index = clubs.firstIndex(where: { $0.id == club.id }) else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            clubs[index].isJoined.toggle()
        }
        generator.impactOccurred()
    }
}

// MARK: - Top Bar (safeAreaBar on iOS 26, safeAreaInset fallback)

private struct ClubsTopBar: ViewModifier {
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    @Namespace private var headerNamespace

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
                .transition(.opacity)

            Spacer()

            searchButton
                .matchedGeometryEffect(id: "searchBar", in: headerNamespace)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var searchButton: some View {
        if #available(iOS 26, *) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isSearchActive = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                .matchedGeometryEffect(id: "searchBar", in: headerNamespace)
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
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
            .transition(.scale(scale: 0.5).combined(with: .opacity))
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
            club.bannerColor
                .frame(height: 120)

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
