import SwiftUI

struct TrackMediaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: SearchMediaCategory? = nil
    @State private var searchResults: [SearchResultItem] = []
    @State private var searchState: SearchState = .idle
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedItem: SearchResultItem?
    @State private var userInterests: [SearchMediaCategory] = []
    @FocusState private var isSearchFocused: Bool

    // Tracking state for the detail view
    @State private var sheetStatus: TrackingStatus?
    @State private var sheetEpisode: Int = 0
    @State private var sheetScore: Int?
    @State private var sheetIsTracking = false
    @State private var sheetIsRated = false

    private var displayedResults: [SearchResultItem] {
        let source: [SearchResultItem] = switch searchState {
        case .idle: SearchView.mockAllMedia
        case .results: searchResults
        case .loading, .noResults: []
        }

        if let filter = selectedFilter {
            return source.filter { $0.category == filter }
        }
        return source
    }

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
                        totalEpisodes: item.totalEpisodes,
                        selectedStatus: $sheetStatus,
                        currentEpisode: $sheetEpisode,
                        userScore: $sheetScore,
                        isTracking: $sheetIsTracking,
                        isRated: $sheetIsRated
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
        .onChange(of: searchText) { _, newValue in
            handleSearchTextChange(newValue)
        }
        .onChange(of: selectedFilter) { _, _ in
            if !searchText.isEmpty {
                handleSearchTextChange(searchText)
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

                    switch searchState {
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
                text: $searchText,
                prompt: Text(searchPlaceholder)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)
            .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
        if let filter = selectedFilter {
            "Search \(filter.label)..."
        } else {
            "Search movies, books, games..."
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", isSelected: selectedFilter == nil) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedFilter = nil
                    }
                }

                ForEach(userInterests) { category in
                    filterChip(
                        label: category.label,
                        dotColor: category.dotColor,
                        isSelected: selectedFilter == category
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedFilter = category
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
        Group {
            sectionHeader("BROWSE")

            ForEach(Array(displayedResults.enumerated()), id: \.element.id) { index, item in
                mediaRow(item)
                    .padding(.horizontal, 24)

                if index < displayedResults.count - 1 {
                    Spacer().frame(height: 24)
                }
            }
        }
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
            let results = displayedResults

            HStack(spacing: 0) {
                sectionHeader("\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                Spacer()
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                mediaRow(item)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

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
            subtitle: selectedFilter != nil
                ? "Try removing the \(selectedFilter!.label) filter or searching for something else"
                : "Try a different search term"
        )
    }

    // MARK: - Media Row (tappable, no action button)

    private func mediaRow(_ item: SearchResultItem) -> some View {
        Button {
            openTracking(for: item)
        } label: {
            HStack(spacing: 16) {
                // Poster
                Group {
                    if let color = item.placeholderColor {
                        color
                    } else {
                        Image(item.imageName)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 64, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 17.78, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: -0.5)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 4) {
                        Text(item.category.uppercaseLabel)
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(item.category.dotColor)

                        Circle()
                            .fill(Color.nook.searchSectionLabel)
                            .frame(width: 3, height: 3)

                        Text(item.year)
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(Color.nook.searchSectionLabel)
                    }

                    Text(item.title)
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.searchBarText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image("star-fill")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Color.nook.reviewRating)

                        Text(String(format: "%.1f", item.rating))
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.reviewRating)

                        Text(item.genres)
                            .font(NookFont.caption.italic())
                            .foregroundStyle(Color.nook.searchSectionLabel)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Chevron
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

    private func openTracking(for item: SearchResultItem) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        sheetStatus = item.selectedStatus
        sheetEpisode = item.currentEpisode
        sheetScore = item.userScore
        sheetIsTracking = item.isTracked
        sheetIsRated = item.userScore != nil
        selectedItem = item

        generator.impactOccurred()
    }

    // MARK: - Search Logic

    private func handleSearchTextChange(_ text: String) {
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                searchState = .idle
                searchResults = []
            }
            return
        }

        withAnimation(.easeOut(duration: 0.15)) {
            searchState = .loading
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        let allMock = SearchView.mockAllMedia
        let lowerQuery = query.lowercased()

        let matched = allMock.filter { item in
            item.title.lowercased().contains(lowerQuery)
                || item.genres.lowercased().contains(lowerQuery)
                || item.category.label.lowercased().contains(lowerQuery)
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                searchResults = matched
                searchState = matched.isEmpty ? .noResults : .results
            }
        }
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
        } catch {
            userInterests = SearchMediaCategory.allCases
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
