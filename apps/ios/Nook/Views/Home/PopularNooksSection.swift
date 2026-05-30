import SwiftUI

// MARK: - Data Model

struct NookItem: Identifiable, Hashable {
    let id = UUID()
    let dbId: UUID?
    let title: String
    let description: String
    let curatorName: String
    let imageName: String
    let imageURL: URL?
    let placeholderColor: Color?
    let likes: Int
    let comments: Int
    let mediaItems: [NookMediaItem]
    let privacy: String
    let layout: String

    init(
        title: String,
        description: String = "",
        curatorName: String,
        imageName: String,
        imageURL: URL? = nil,
        placeholderColor: Color? = nil,
        likes: Int = 0,
        comments: Int = 0,
        mediaItems: [NookMediaItem] = [],
        privacy: String = "Public",
        layout: String = "Grid",
        dbId: UUID? = nil
    ) {
        self.title = title
        self.description = description
        self.curatorName = curatorName
        self.imageName = imageName
        self.imageURL = imageURL
        self.placeholderColor = placeholderColor
        self.likes = likes
        self.comments = comments
        self.mediaItems = mediaItems
        self.privacy = privacy
        self.layout = layout
        self.dbId = dbId
    }

    init(from detail: NookDetail) {
        self.dbId = detail.nook.id
        self.title = detail.nook.name
        self.description = detail.nook.description ?? ""
        self.curatorName = detail.ownerName ?? "Unknown"
        self.imageName = ""
        self.imageURL = detail.nook.coverURL
        self.placeholderColor = nil
        self.likes = 0
        self.comments = 0
        self.mediaItems = detail.items.map { NookMediaItem(from: $0) }
        self.privacy = detail.nook.privacy.capitalized
        self.layout = detail.nook.layout.capitalized
    }

    init(from row: NookRow) {
        self.dbId = row.id
        self.title = row.name
        self.description = row.description ?? ""
        self.curatorName = ""
        self.imageName = ""
        self.imageURL = row.coverUrl.flatMap { URL(string: $0) }
        self.placeholderColor = nil
        self.likes = 0
        self.comments = 0
        self.mediaItems = []
        self.privacy = row.privacy.capitalized
        self.layout = row.layout.capitalized
    }
}

struct NookMediaItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let category: String
    let year: String
    let imageName: String
    let imageURL: URL?
    let placeholderColor: Color?
    let note: String?

    init(
        title: String,
        category: String,
        year: String,
        imageName: String,
        imageURL: URL? = nil,
        placeholderColor: Color? = nil,
        note: String? = nil
    ) {
        self.title = title
        self.category = category
        self.year = year
        self.imageName = imageName
        self.imageURL = imageURL
        self.placeholderColor = placeholderColor
        self.note = note
    }

    init(from entry: NookMediaEntry) {
        self.title = entry.title
        self.category = entry.mediaType.uppercased()
        self.year = ""
        self.imageName = ""
        self.imageURL = entry.imageURL
        self.placeholderColor = nil
        self.note = entry.note
    }
}

// MARK: - Section

struct PopularNooksSection: View {
    let items: [NookItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            scrollContent
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Popular Nooks")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()

            Button {
                // TODO: Discover action
            } label: {
                Text("Discover")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.sectionAction)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        NookCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Card

private struct NookCard: View {
    let item: NookItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or placeholder
            Group {
                if let url = item.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            (item.placeholderColor ?? Color.nook.foreground)
                        }
                    }
                } else if let color = item.placeholderColor {
                    color
                } else if !item.imageName.isEmpty {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.nook.foreground
                }
            }
            .frame(width: 354)
            .aspectRatio(402.0 / 394.0, contentMode: .fill)
            .clipped()

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.8), location: 0),
                    .init(color: .black.opacity(0.2), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.custom("Outfit-Bold", size: 24))
                    .lineSpacing(2)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                // Curator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )

                    Text("CURATED BY \(item.curatorName.uppercased())")
                        .font(.custom("PlusJakartaSans-Medium", size: 10))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(24)
        }
        .frame(width: 354)
        .aspectRatio(402.0 / 394.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg))
    }
}

// MARK: - Mock Data

extension PopularNooksSection {
    static let mockItems: [NookItem] = [
        NookItem(
            title: "Books and films that feel like autumn",
            description: "A cozy collection of stories that capture the warmth of golden leaves, warm drinks, and that quiet feeling of change. Perfect for rainy afternoons.",
            curatorName: "Sarah",
            imageName: "mock-autumn-nook",
            placeholderColor: Color(hex: 0x5C3A1E),
            likes: 234,
            comments: 18,
            mediaItems: [
                NookMediaItem(title: "The Midnight Garden", category: "MOVIE", year: "2025", imageName: "mock-midnight-garden", placeholderColor: Color(hex: 0x2D4A3E), note: "The cinematography in this one is unreal"),
                NookMediaItem(title: "Foundation's Edge", category: "BOOK", year: "1982", imageName: "mock-foundations-edge", placeholderColor: Color(hex: 0xD4A373), note: "Asimov at his most contemplative"),
                NookMediaItem(title: "Frieren: Beyond Journey's End", category: "ANIME", year: "2023", imageName: "mock-frieren", placeholderColor: Color(hex: 0x9B8EC4)),
                NookMediaItem(title: "Project Hail Mary", category: "BOOK", year: "2021", imageName: "mock-hail-mary", placeholderColor: Color(hex: 0x2C3E50), note: "This book made me cry on a plane"),
                NookMediaItem(title: "The Cloud Weaver", category: "ANIME", year: "2024", imageName: "mock-cloud-weaver", placeholderColor: Color(hex: 0x87CEEB)),
            ]
        ),
        NookItem(
            title: "Sci-fi worlds that feel lived in",
            description: "Not the shiny utopias — the ones with rust and history. Worlds that feel like someone actually lives there.",
            curatorName: "James",
            imageName: "mock-scifi-nook",
            placeholderColor: Color(hex: 0x1A2940),
            likes: 189,
            comments: 12,
            mediaItems: [
                NookMediaItem(title: "Astris", category: "MOVIE", year: "2023", imageName: "mock-astris", placeholderColor: Color(hex: 0x2C3E50)),
                NookMediaItem(title: "Severance", category: "TV SHOW", year: "2022", imageName: "mock-severance", placeholderColor: Color(hex: 0x3B5998)),
                NookMediaItem(title: "Dune: Part Three", category: "MOVIE", year: "2026", imageName: "mock-dune", placeholderColor: Color(hex: 0xC2A059)),
            ]
        ),
        NookItem(
            title: "Stories that hit different at night",
            description: "The kind of stories you stay up way too late for. Atmospheric, emotional, and impossible to put down.",
            curatorName: "Mia",
            imageName: "mock-night-nook",
            placeholderColor: Color(hex: 0x2D1B4E),
            likes: 156,
            comments: 9,
            mediaItems: [
                NookMediaItem(title: "Dandadan", category: "ANIME", year: "2024", imageName: "mock-dandadan", placeholderColor: Color(hex: 0xE84393)),
                NookMediaItem(title: "Chainsaw Man", category: "MANGA", year: "2018", imageName: "mock-chainsaw-man", placeholderColor: Color(hex: 0xD63031)),
            ]
        ),
    ]
}

// MARK: - Preview

#Preview {
    ScrollView {
        PopularNooksSection(items: PopularNooksSection.mockItems)
    }
    .background(Color.nook.background)
}
