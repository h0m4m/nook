import SwiftUI

// MARK: - Activity Feed Item Type

enum ActivityFeedType: Hashable {
    case rated(mediaTitle: String, rating: Double)
    case started(mediaTitle: String)
    case completed(mediaTitle: String)
    case reviewed(mediaTitle: String, rating: Double, excerpt: String)
    case clubPost(clubName: String, body: String, imageName: String?, placeholderColor: Color?)

    var isPost: Bool {
        switch self {
        case .clubPost, .reviewed: true
        default: false
        }
    }
}

// MARK: - Data Model

struct ActivityFeedItem: Identifiable, Hashable {
    let id = UUID()
    let userId: UUID?
    let userName: String
    let timeAgo: String
    let type: ActivityFeedType
    let likes: String?
    let comments: String?

    static func == (lhs: ActivityFeedItem, rhs: ActivityFeedItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(
        userName: String,
        timeAgo: String,
        type: ActivityFeedType,
        likes: String? = nil,
        comments: String? = nil,
        userId: UUID? = nil
    ) {
        self.userId = userId
        self.userName = userName
        self.timeAgo = timeAgo
        self.type = type
        self.likes = likes
        self.comments = comments
    }

    init(from entry: ActivityFeedEntry) {
        self.userId = entry.userId
        self.userName = entry.userName
        self.timeAgo = ""
        self.likes = nil
        self.comments = nil

        let mediaTitle = entry.mediaTitle ?? "something"
        switch entry.actionType {
        case "tracked":
            self.type = .started(mediaTitle: mediaTitle)
        case "completed":
            self.type = .completed(mediaTitle: mediaTitle)
        case "reviewed":
            self.type = .reviewed(mediaTitle: mediaTitle, rating: 0, excerpt: "")
        default:
            self.type = .started(mediaTitle: mediaTitle)
        }
    }
}

// MARK: - Section

struct ActivityFeedSection: View {
    let items: [ActivityFeedItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            scrollContent
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text("Activity")
                .font(NookFont.outfitHeadingSmall)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()

            Button {
                // TODO: See all action
            } label: {
                Text("See all")
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
                    if item.type.isPost {
                        PostActivityCard(item: item)
                    } else {
                        CompactActivityCard(item: item)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Post Activity Card (club posts & reviews)

private struct PostActivityCard: View {
    let item: ActivityFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.top, 21)
                .padding(.horizontal, 21)

            cardBody
                .padding(.top, 12)
                .padding(.horizontal, 21)

            if case .clubPost(_, _, let imageName, let placeholderColor) = item.type,
               imageName != nil || placeholderColor != nil {
                postImage(imageName: imageName, placeholderColor: placeholderColor)
                    .padding(.top, 12)
                    .padding(.horizontal, 21)
            }

            Spacer(minLength: 0)

            if let likes = item.likes, let comments = item.comments {
                cardFooter(likes: likes, comments: comments)
                    .padding(.horizontal, 21)
                    .padding(.bottom, 21)
            }
        }
        .frame(width: 300, height: 230)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.nook.mutedForeground)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.userName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.cardTitle)
                        .lineLimit(1)

                    headerSubtitle
                }
            }

            Spacer()

            headerTrailing
        }
    }

    @ViewBuilder
    private var headerSubtitle: some View {
        switch item.type {
        case .reviewed(let title, _, _):
            HStack(spacing: 2) {
                Text("reviewed")
                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                    .foregroundStyle(Color.nook.cardSubtitle)
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(1)
            }

        case .clubPost(let clubName, _, _, _):
            HStack(spacing: 2) {
                Text("posted in")
                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                    .foregroundStyle(Color.nook.cardSubtitle)
                Text(clubName)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .foregroundStyle(Color.nook.activityClubName)
                    .lineLimit(1)
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var headerTrailing: some View {
        switch item.type {
        case .reviewed(_, let rating, _):
            ratingBadge(rating)

        default:
            Text(item.timeAgo)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.cardSubtitle)
        }
    }

    private func ratingBadge(_ rating: Double) -> some View {
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

    // MARK: - Body

    @ViewBuilder
    private var cardBody: some View {
        switch item.type {
        case .reviewed(_, _, let excerpt):
            Text("\"\(excerpt)\"")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.reviewBody)
                .lineSpacing(6)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .clubPost(_, let body, _, _):
            Text(body)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)
                .lineSpacing(5)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

        default:
            EmptyView()
        }
    }

    // MARK: - Post Image

    private func postImage(imageName: String?, placeholderColor: Color?) -> some View {
        Group {
            if let color = placeholderColor {
                color
            } else if let name = imageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
    }

    // MARK: - Footer

    private func cardFooter(likes: String, comments: String) -> some View {
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
    }
}

// MARK: - Compact Activity Card (rated, started, completed)

private struct CompactActivityCard: View {
    let item: ActivityFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.top, 21)
                .padding(.horizontal, 21)

            cardBody
                .padding(.top, 10)
                .padding(.horizontal, 21)

            Spacer(minLength: 0)
        }
        .frame(width: 220, height: 230)
        .background(Color.nook.card)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.nook.secondary)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(item.userName)
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(1)

                headerSubtitle
            }

            Spacer(minLength: 0)

            Text(item.timeAgo)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.cardSubtitle)
        }
    }

    @ViewBuilder
    private var headerSubtitle: some View {
        switch item.type {
        case .rated(let title, _):
            HStack(spacing: 2) {
                Text("rated")
                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                    .foregroundStyle(Color.nook.cardSubtitle)
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(1)
            }

        case .started(let title):
            HStack(spacing: 2) {
                Text("started")
                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                    .foregroundStyle(Color.nook.cardSubtitle)
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(1)
            }

        case .completed(let title):
            HStack(spacing: 2) {
                Text("finished")
                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                    .foregroundStyle(Color.nook.cardSubtitle)
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 10))
                    .foregroundStyle(Color.nook.cardTitle)
                    .lineLimit(1)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var cardBody: some View {
        switch item.type {
        case .rated(_, let rating):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Image("star-fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text(String(format: "%.0f", rating))
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.detailRatingText)

                    Text("/ 10")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.cardSubtitle)
                }
                .padding(.horizontal, 6.5)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6.39, style: .continuous)
                        .fill(Color.nook.detailRatingBadge)
                )

                Text(ratingLabel(for: rating))
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }

        case .started:
            Text("Started tracking")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.cardSubtitle)

        case .completed:
            Text("Completed!")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.libraryStatusActive)

        default:
            EmptyView()
        }
    }

    private func ratingLabel(for rating: Double) -> String {
        switch rating {
        case 10: "Masterpiece"
        case 9..<10: "Amazing"
        case 8..<9: "Great"
        case 7..<8: "Good"
        case 6..<7: "Fine"
        case 5..<6: "Mid"
        case 4..<5: "Bad"
        case 3..<4: "Terrible"
        default: "Appalling"
        }
    }
}

// MARK: - Mock Data

extension ActivityFeedSection {
    static let mockItems: [ActivityFeedItem] = [
        ActivityFeedItem(
            userName: "Aria Chen",
            timeAgo: "2h",
            type: .rated(mediaTitle: "Frieren", rating: 9)
        ),
        ActivityFeedItem(
            userName: "Marcus",
            timeAgo: "3h",
            type: .clubPost(
                clubName: "Sci-Fi Cinema",
                body: "Just finished Dune: Part Three and I'm speechless. The way Villeneuve wrapped up the saga is nothing short of cinematic perfection.",
                imageName: nil,
                placeholderColor: nil
            ),
            likes: "86",
            comments: "12"
        ),
        ActivityFeedItem(
            userName: "Elena Vance",
            timeAgo: "5h",
            type: .reviewed(
                mediaTitle: "Severance",
                rating: 9.2,
                excerpt: "Season 3 somehow tops everything. The writing has never been tighter and the performances are unreal."
            ),
            likes: "142",
            comments: "18"
        ),
        ActivityFeedItem(
            userName: "James",
            timeAgo: "8h",
            type: .clubPost(
                clubName: "Anime Corner",
                body: "Hot take: Dandadan is the most creative anime to come out in years. The way it blends horror, comedy, and romance is wild.",
                imageName: nil,
                placeholderColor: nil
            ),
            likes: "215",
            comments: "34"
        ),
        ActivityFeedItem(
            userName: "Sarah",
            timeAgo: "12h",
            type: .completed(mediaTitle: "Project Hail Mary")
        ),
    ]
}

// MARK: - Preview

#Preview {
    ScrollView {
        ActivityFeedSection(items: ActivityFeedSection.mockItems)
    }
    .background(Color.nook.background)
}
