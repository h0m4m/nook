import SwiftUI

// MARK: - Route

struct DiscoverNooksRoute: Hashable {}

// MARK: - Discover Nooks

struct DiscoverNooksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nooks: [NookSummary] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                loadingGrid
            } else if nooks.isEmpty {
                SearchEmptyState(
                    icon: "squares-four-fill",
                    title: "No nooks to discover yet",
                    subtitle: "Public nooks created by the community will show up here"
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(nooks) { summary in
                        NavigationLink(value: NookItem(from: summary)) {
                            DiscoverNookCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .modifier(DiscoverSoftScrollEdge())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.nook.background)
        .modifier(DiscoverTopBar(onBack: { dismiss() }))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let service = NookService()
        nooks = (try? await service.getPopularNooks(limit: 50)) ?? []
        isLoading = false
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                        .fill(Color.nook.searchShimmerBase)
                        .aspectRatio(402.0 / 394.0, contentMode: .fit)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 90, height: 12)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

// MARK: - Card

private struct DiscoverNookCard: View {
    let summary: NookSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                MediaPosterImage(
                    url: summary.coverURL,
                    width: 999,
                    height: 999,
                    cornerRadius: NookRadii.sm,
                    fallbackColor: Color.nook.searchShimmerBase
                )
                .aspectRatio(402.0 / 394.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                        .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
                )

                if summary.likesCount > 0 {
                    HStack(spacing: 4) {
                        Image("heart-fill")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 11, height: 11)
                            .foregroundStyle(.white)
                        Text("\(summary.likesCount)")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 11))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(8)
                }
            }

            Text(summary.name)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.cardTitle)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Text(summary.ownerName.map { "by \($0)" } ?? "")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(summary.itemCount)")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.cardSubtitle)
                Image("squares-four-fill")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 11, height: 11)
                    .foregroundStyle(Color.nook.cardSubtitle)
            }
        }
    }
}

// MARK: - Top Bar

private struct DiscoverTopBar: ViewModifier {
    let onBack: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                bar.padding(.top, 4).padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                bar
                    .background(Color.nook.background)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            backButton

            Text("Discover Nooks")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.sectionTitle)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var backButton: some View {
        if #available(iOS 26, *) {
            Button(action: onBack) {
                Image("caret-left-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onBack) {
                Image("caret-left-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.sectionTitle)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DiscoverSoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}
