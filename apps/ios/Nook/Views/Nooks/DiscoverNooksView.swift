import SwiftUI

// MARK: - Route

struct DiscoverNooksRoute: Hashable {}

// MARK: - Discover Nooks

struct DiscoverNooksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nooks: [NookSummary] = []
    @State private var isLoading = true

    private var visibleNooks: [NookSummary] {
        nooks.filter { !BlockStore.shared.isBlocked($0.userId) }
    }

    var body: some View {
        ScrollView {
            if isLoading {
                loadingList
            } else if visibleNooks.isEmpty {
                SearchEmptyState(
                    icon: "squares-four-fill",
                    title: "No nooks to discover yet",
                    subtitle: "Public nooks created by the community will show up here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(visibleNooks) { summary in
                        NavigationLink(value: NookItem(from: summary)) {
                            NookCard(item: NookItem(from: summary), width: nil)
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

    private var loadingList: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.nook.searchShimmerBase)
                                .frame(width: 60, height: 90)
                        }
                        Spacer(minLength: 0)
                    }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.nook.searchShimmerBase)
                        .frame(width: 120, height: 12)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.nook.card)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
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
