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
    var isJoined: Bool

    init(
        name: String,
        memberCount: String,
        description: String,
        category: CommunityFilter,
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
            filterChips
            communityList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.nook.searchBackground)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            Text("Communities")
                .font(NookFont.headingLarge)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()

            Button {
                // No action
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
        .padding(.horizontal, 24)
        .padding(.top, 8)
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
            community.bannerColor
                .frame(height: 120)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title + Join button
                HStack(alignment: .center) {
                    Text(community.name)
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

                    Text(community.memberCount)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }

                // Description
                Text(community.description)
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

    // MARK: - Join Button

    private var joinButton: some View {
        Button(action: onToggleJoined) {
            HStack(spacing: 4) {
                if community.isJoined {
                    Image("check-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }

                Text(community.isJoined ? "Joined" : "Join")
                    .font(NookFont.labelBoldSmall)
            }
            .foregroundStyle(community.isJoined ? .white : Color.nook.searchFilterText)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(community.isJoined ? Color.nook.searchAddedButton : Color.nook.card)
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
            bannerColor: Color(hex: 0xBA68C8).opacity(0.3)
        ),
        CommunityItem(
            name: "Cozy Book Club",
            memberCount: "12.1k Members",
            description: "Monthly reads, candle-lit aesthetics, and warm discussions about your favorite literary",
            category: .books,
            bannerColor: Color(hex: 0xD4A373).opacity(0.3),
            isJoined: true
        ),
        CommunityItem(
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
    CommunitiesView()
}
