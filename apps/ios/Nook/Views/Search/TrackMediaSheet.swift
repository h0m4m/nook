import SwiftUI

struct TrackMediaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @State private var selectedItem: MediaSearchResult?
    @State private var userInterests: [SearchMediaCategory] = []
    @FocusState private var isSearchFocused: Bool

    // Tracking state for the detail view
    @State private var sheetStatus: TrackingStatus?
    @State private var sheetEpisode: Int = 0
    @State private var sheetScore: Int?
    @State private var sheetIsTracking = false
    @State private var sheetIsRated = false

    var body: some View {
        NavigationStack {
            searchContent
                .background(Color.nook.searchBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image("x-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundStyle(Color.nook.detailMeta)
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Track Media")
                            .font(NookFont.labelBoldSmall)
                            .foregroundStyle(Color.nook.detailTitle)
                    }
                }
                .navigationDestination(item: $selectedItem) { item in
                    TrackingSheetView(
                        mediaTitle: item.title,
                        totalEpisodes: 0,
                        category: LibraryMediaCategory.from(apiMediaType: item.mediaType),
                        selectedStatus: $sheetStatus,
                        currentEpisode: $sheetEpisode,
                        userScore: $sheetScore,
                        isTracking: $sheetIsTracking,
                        isRated: $sheetIsRated
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.search()
        }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            if !viewModel.searchText.isEmpty {
                viewModel.search()
            }
        }
        .onChange(of: sheetIsTracking) { old, new in
            if !old && new {
                dismiss()
            }
        }
        .task {
            await loadUserInterests()
        }
    }

    // MARK: - Search Content

    private var searchContent: some View {
        VStack(spacing: 0) {
            searchBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    filterChips

                    switch viewModel.searchState {
                    case .idle:
                        idleContent
                    case .loading:
                        loadingContent
                    case .results:
                        resultsContent
                    case .noResults:
                        noResultsContent
                    }
                }
                .padding(.bottom, 40)
            }
            .modifier(SoftScrollEdge())
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            TextField(
                searchPlaceholder,
                text: $viewModel.searchText,
                prompt: Text(searchPlaceholder)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)
            .focused($isSearchFocused)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nook.searchBarPlaceholder)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .modifier(SearchBarBackground())
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var searchPlaceholder: String {
        if let filter = viewModel.selectedFilter {
            "Search \(filter.label)..."
        } else {
            "Search movies, books, anime..."
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(userInterests) { category in
                    filterChip(
                        label: category.label,
                        dotColor: category.dotColor,
                        isSelected: viewModel.selectedFilter == category
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.selectedFilter = category
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private func filterChip(
        label: String,
        dotColor: Color? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let dotColor, !isSelected {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(label)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .padding(.horizontal, isSelected && dotColor == nil ? 22.5 : 20)
                .frame(height: 38)
                .background(
                    isSelected ? Color.nook.searchFilterSelected : .white,
                    in: Capsule()
                )
                .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let dotColor, !isSelected {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(label)
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isSelected ? .white : Color.nook.searchFilterText)
                }
                .padding(.horizontal, isSelected && dotColor == nil ? 22.5 : 20)
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

    // MARK: - Content States

    private var idleContent: some View {
        SearchEmptyState(
            icon: "magnifying-glass-bold",
            title: "Search to track",
            subtitle: "Find movies, shows, anime, books, and manga to track"
        )
    }

    private var loadingContent: some View {
        VStack(spacing: 24) {
            ForEach(0..<4, id: \.self) { _ in
                SearchShimmerRow()
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 8)
    }

    private var resultsContent: some View {
        Group {
            let results = viewModel.results

            HStack(spacing: 0) {
                sectionHeader("\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                Spacer()
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                mediaRow(item)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onAppear {
                        if item.id == results.last?.id {
                            viewModel.loadNextPage()
                        }
                    }

                if index < results.count - 1 {
                    Spacer().frame(height: 24)
                }
            }
        }
    }

    private var noResultsContent: some View {
        SearchEmptyState(
            icon: "magnifying-glass-bold",
            title: "No results found",
            subtitle: viewModel.selectedFilter != nil
                ? "Try removing the \(viewModel.selectedFilter!.label) filter or searching for something else"
                : "Try a different search term"
        )
    }

    // MARK: - Media Row (tappable, no action button)

    private func mediaRow(_ item: MediaSearchResult) -> some View {
        let category = SearchMediaCategory.from(apiMediaType: item.mediaType)

        return Button {
            openTracking(for: item)
        } label: {
            HStack(spacing: 16) {
                MediaPosterImage(
                    url: item.imageURL,
                    width: 64,
                    height: 80,
                    fallbackColor: category?.dotColor.opacity(0.3) ?? Color.nook.searchShimmerBase
                )
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 4) {
                        if let cat = category {
                            Text(cat.uppercaseLabel)
                                .font(NookFont.tabLabel)
                                .tracking(0.5)
                                .foregroundStyle(cat.dotColor)
                        }

                        if item.year != nil {
                            Circle()
                                .fill(Color.nook.searchSectionLabel)
                                .frame(width: 3, height: 3)

                            Text(item.year ?? "")
                                .font(NookFont.tabLabel)
                                .tracking(0.5)
                                .foregroundStyle(Color.nook.searchSectionLabel)
                        }
                    }

                    Text(item.title)
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.searchBarText)
                        .lineLimit(1)

                    if let score = item.score {
                        HStack(spacing: 6) {
                            Image("star-fill")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                                .foregroundStyle(Color.nook.reviewRating)

                            Text(String(format: "%.1f", score))
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.reviewRating)
                        }
                    }
                }

                Spacer(minLength: 8)

                Image("caret-left-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.nook.searchSectionLabel)
                    .rotationEffect(.degrees(180))
            }
            .frame(height: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(NookFont.tabLabel)
            .tracking(1)
            .foregroundStyle(Color.nook.searchSectionLabel)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
    }

    // MARK: - Tracking

    private func openTracking(for item: MediaSearchResult) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        sheetStatus = nil
        sheetEpisode = 0
        sheetScore = nil
        sheetIsTracking = false
        sheetIsRated = false
        selectedItem = item

        generator.impactOccurred()
    }

    private func loadUserInterests() async {
        guard let user = try? await supabase.auth.session.user else { return }
        let userId = user.id

        struct ProfileRow: Decodable {
            let interests: [String]?
        }

        do {
            let row: ProfileRow = try await supabase
                .from("user_profiles")
                .select("interests")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            if let interests = row.interests {
                userInterests = SearchMediaCategory.allCases.filter {
                    interests.contains($0.rawValue)
                }
            }
            if viewModel.selectedFilter == nil {
                viewModel.selectedFilter = userInterests.first ?? .movies
            }
        } catch {
            userInterests = SearchMediaCategory.allCases
            if viewModel.selectedFilter == nil {
                viewModel.selectedFilter = userInterests.first ?? .movies
            }
        }
    }
}

// MARK: - Search State (shared)

enum SearchState: Equatable {
    case idle
    case loading
    case results
    case noResults
}
