import SwiftUI

// MARK: - Data Model

struct NookItem: Identifiable, Hashable {
    let id = UUID()
    let dbId: UUID?
    let ownerUserId: UUID?
    let title: String
    let description: String
    let curatorName: String
    let curatorAvatarURL: URL?
    let imageName: String
    let imageURL: URL?
    let placeholderColor: Color?
    let likes: Int
    let comments: Int
    let createdAt: Date?
    let mediaItems: [NookMediaItem]
    let privacy: String

    init(
        title: String,
        description: String = "",
        curatorName: String,
        curatorAvatarURL: URL? = nil,
        imageName: String = "",
        imageURL: URL? = nil,
        placeholderColor: Color? = nil,
        likes: Int = 0,
        comments: Int = 0,
        createdAt: Date? = nil,
        mediaItems: [NookMediaItem] = [],
        privacy: String = "public",
        dbId: UUID? = nil,
        ownerUserId: UUID? = nil
    ) {
        self.dbId = dbId
        self.ownerUserId = ownerUserId
        self.title = title
        self.description = description
        self.curatorName = curatorName
        self.curatorAvatarURL = curatorAvatarURL
        self.imageName = imageName
        self.imageURL = imageURL
        self.placeholderColor = placeholderColor
        self.likes = likes
        self.comments = comments
        self.createdAt = createdAt
        self.mediaItems = mediaItems
        self.privacy = privacy
    }

    init(from detail: NookDetail) {
        self.dbId = detail.nook.id
        self.ownerUserId = detail.nook.userId
        self.title = detail.nook.name
        self.description = detail.nook.description ?? ""
        self.curatorName = detail.ownerName ?? "Unknown"
        self.curatorAvatarURL = detail.ownerAvatarURL
        self.imageName = ""
        self.imageURL = nil
        self.placeholderColor = nil
        self.likes = detail.nook.likesCount
        self.comments = 0
        self.createdAt = detail.nook.createdAt
        self.mediaItems = detail.items.map { NookMediaItem(from: $0) }
        self.privacy = detail.nook.privacy
    }

    init(from summary: NookSummary) {
        self.dbId = summary.id
        self.ownerUserId = summary.userId
        self.title = summary.name
        self.description = summary.description ?? ""
        self.curatorName = summary.ownerName ?? "Unknown"
        self.curatorAvatarURL = summary.ownerAvatarURL
        self.imageName = ""
        self.imageURL = nil
        self.placeholderColor = nil
        self.likes = summary.likesCount
        self.comments = 0
        self.createdAt = summary.createdAt
        // Preview posters of the media inside the nook (no cover image).
        self.mediaItems = summary.previewImageURLs.map {
            NookMediaItem(title: "", category: "", year: "", imageName: "", imageURL: $0)
        }
        self.privacy = summary.privacy
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

            NavigationLink(value: DiscoverNooksRoute()) {
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

struct NookCard: View {
    let item: NookItem
    var width: CGFloat? = 300
    var showCurator: Bool = true

    private let posterWidth: CGFloat = 60
    private let posterHeight: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            posterShelf

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.custom("Outfit-Bold", size: 20))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .foregroundStyle(Color.nook.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showCurator {
                    HStack(spacing: 8) {
                        curatorAvatar

                        Text("CURATED BY \(item.curatorName.uppercased())")
                            .font(.custom("PlusJakartaSans-Medium", size: 10))
                            .tracking(0.5)
                            .foregroundStyle(Color.nook.cardSubtitle)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: width, alignment: .leading)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
    }

    // Posters of the media inside the nook, lined up like a shelf.
    // If there are more than 4, the 4th shows a "+N" overflow badge.
    private var posterShelf: some View {
        let posters = Array(item.mediaItems.prefix(4))
        let overflow = item.mediaItems.count - posters.count
        return HStack(spacing: 8) {
            if posters.isEmpty {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: posterWidth, height: posterHeight)
                }
            } else {
                ForEach(Array(posters.enumerated()), id: \.offset) { index, media in
                    MediaPosterImage(
                        url: media.imageURL,
                        width: posterWidth,
                        height: posterHeight,
                        cornerRadius: 10,
                        fallbackColor: Color.nook.searchShimmerBase
                    )
                    .overlay {
                        if index == 3 && overflow > 0 {
                            ZStack {
                                Color.black.opacity(0.55)
                                Text("+\(overflow)")
                                    .font(.custom("Outfit-Bold", size: 20))
                                    .foregroundStyle(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: posterHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var curatorAvatar: some View {
        Group {
            if let url = item.curatorAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarFallback
                    }
                }
            } else {
                avatarFallback
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.nook.border, lineWidth: 1)
        )
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color.nook.secondary)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.nook.mutedForeground)
            )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        PopularNooksSection(items: [
            NookItem(
                title: "Books and films that feel like autumn",
                curatorName: "Sarah",
                placeholderColor: Color(hex: 0x5C3A1E),
                likes: 234
            ),
            NookItem(
                title: "Sci-fi worlds that feel lived in",
                curatorName: "James",
                placeholderColor: Color(hex: 0x1A2940),
                likes: 189
            ),
        ])
    }
    .background(Color.nook.background)
}
