import SwiftUI

// MARK: - Community Filter

enum CommunityFilter: CaseIterable, Identifiable {
    case discover
    case movies
    case tvShows
    case anime
    case manga
    case books
    case games

    var id: String {
        switch self {
        case .discover: "discover"
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
        case .discover: "Discover"
        case .movies: "Movies"
        case .tvShows: "TV Shows"
        case .anime: "Anime"
        case .manga: "Manga"
        case .books: "Books"
        case .games: "Games"
        }
    }
}

// MARK: - Community Model

struct CommunityItem: Identifiable {
    let id = UUID()
    let name: String
    let memberCount: String
    let description: String
    let category: CommunityFilter
    let bannerColor: Color
    let iconColor: Color
    var isJoined: Bool

    init(
        name: String,
        memberCount: String,
        description: String,
        category: CommunityFilter,
        bannerColor: Color,
        iconColor: Color,
        isJoined: Bool = false
    ) {
        self.name = name
        self.memberCount = memberCount
        self.description = description
        self.category = category
        self.bannerColor = bannerColor
        self.iconColor = iconColor
        self.isJoined = isJoined
    }
}

// MARK: - Communities View

struct CommunitiesView: View {
    @State private var selectedFilter: CommunityFilter = .discover
    @State private var communities: [CommunityItem] = CommunitiesView.mockCommunities

    private var filteredCommunities: [CommunityItem] {
        if selectedFilter == .discover {
            return communities
        }
        return communities.filter { $0.category == selectedFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            searchBar
            filterChips
            communityList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.nook.searchBackground)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Communities")
                .font(NookFont.headingLarge)
                .foregroundStyle(Color.nook.sectionTitle)

            Text("Find your people and share your taste.")
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.cardSubtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            Text("Search communities...")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.nook.searchBarBackground)
        .clipShape(Capsule())
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommunityFilter.allCases) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func filterChip(_ filter: CommunityFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.label)
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

    // MARK: - Community List

    private var communityList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(Array(filteredCommunities.enumerated()), id: \.element.id) { index, community in
                    CommunityCard(community: community) {
                        toggleJoined(community)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Actions

    private func toggleJoined(_ community: CommunityItem) {
        guard let index = communities.firstIndex(where: { $0.id == community.id }) else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            communities[index].isJoined.toggle()
        }
        generator.impactOccurred()
    }
}

// MARK: - Community Card

private struct CommunityCard: View {
    let community: CommunityItem
    let onToggleJoined: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            banner

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Icon row + join button
                iconAndJoinRow
                    .padding(.top, -22)

                // Member count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nook.cardSubtitle)

                    Text(community.memberCount)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }
                .padding(.top, 2)

                // Description
                Text(community.description)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.cardSubtitle)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    // MARK: - Banner

    private var banner: some View {
        community.bannerColor
            .frame(height: 100)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: NookRadii.sm,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: NookRadii.sm,
                    style: .continuous
                )
            )
    }

    // MARK: - Icon + Join Row

    private var iconAndJoinRow: some View {
        HStack(alignment: .bottom) {
            // Community icon
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(community.iconColor)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.nook.card, lineWidth: 3)
                )

            Text(community.name)
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.cardTitle)
                .lineLimit(1)
                .padding(.bottom, 2)

            Spacer()

            // Join / Joined button
            joinButton
                .padding(.bottom, 2)
        }
    }

    private var joinButton: some View {
        Button(action: onToggleJoined) {
            HStack(spacing: 4) {
                if community.isJoined {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }

                Text(community.isJoined ? "Joined" : "Join")
                    .font(NookFont.labelBoldSmall)
            }
            .foregroundStyle(community.isJoined ? .white : Color.nook.searchFilterText)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(community.isJoined ? Color.nook.searchAddedButton : Color.white)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        community.isJoined ? Color.clear : Color.nook.searchFilterBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mock Data

extension CommunitiesView {
    static let mockCommunities: [CommunityItem] = [
        CommunityItem(
            name: "Anime Corner",
            memberCount: "24.5k Members",
            description: "The ultimate spot for seasonal discussions, recommendation threads, and sharing your",
            category: .anime,
            bannerColor: Color(hex: 0xBA68C8).opacity(0.3),
            iconColor: Color(hex: 0xBA68C8)
        ),
        CommunityItem(
            name: "Cozy Book Club",
            memberCount: "12.1k Members",
            description: "Monthly reads, candle-lit aesthetics, and warm discussions about your favorite literary",
            category: .books,
            bannerColor: Color(hex: 0xD4A373).opacity(0.3),
            iconColor: Color(hex: 0xD4A373),
            isJoined: true
        ),
        CommunityItem(
            name: "Film Lovers",
            memberCount: "45.8k Members",
            description: "From blockbuster hits to indie gems. Review swap and nightly watch-party threads.",
            category: .movies,
            bannerColor: Color(hex: 0xE57373).opacity(0.3),
            iconColor: Color(hex: 0xE57373)
        ),
    ]
}

// MARK: - Preview

#Preview {
    CommunitiesView()
}
