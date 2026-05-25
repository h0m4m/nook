import SwiftUI

// MARK: - Data Model

struct NookItem: Identifiable {
    let id = UUID()
    let title: String
    let curatorName: String
    let imageName: String
    let placeholderColor: Color?

    init(title: String, curatorName: String, imageName: String, placeholderColor: Color? = nil) {
        self.title = title
        self.curatorName = curatorName
        self.imageName = imageName
        self.placeholderColor = placeholderColor
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
                    NookCard(item: item)
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
                if let color = item.placeholderColor {
                    color
                } else {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 354, height: 192)
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
        .frame(width: 354, height: 192)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg))
    }
}

// MARK: - Mock Data

extension PopularNooksSection {
    static let mockItems: [NookItem] = [
        NookItem(
            title: "Books and films that feel like autumn",
            curatorName: "Sarah",
            imageName: "mock-autumn-nook",
            placeholderColor: Color(hex: 0x5C3A1E)
        ),
        NookItem(
            title: "Sci-fi worlds that feel lived in",
            curatorName: "James",
            imageName: "mock-scifi-nook",
            placeholderColor: Color(hex: 0x1A2940)
        ),
        NookItem(
            title: "Stories that hit different at night",
            curatorName: "Mia",
            imageName: "mock-night-nook",
            placeholderColor: Color(hex: 0x2D1B4E)
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
