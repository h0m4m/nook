import PhotosUI
import SwiftUI

/// Polls always run for exactly one day.
private let pollDurationSeconds: TimeInterval = 86_400

struct ComposePostView: View {
    let clubName: String
    var clubId: UUID?
    var accent: Color = Color.nook.primary
    @Environment(\.dismiss) private var dismiss
    @State private var postBody = ""
    @State private var attachedImages: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isPosting = false
    @State private var showPoll = false
    @State private var pollOptions: [String] = ["", ""]
    @State private var attachedMedia: [MediaSearchResult] = []
    @State private var showMediaPicker = false
    @FocusState private var isBodyFocused: Bool

    @FocusState private var focusedPollOption: Int?

    private var canPost: Bool {
        let hasText = !postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !attachedImages.isEmpty
        let hasMedia = !attachedMedia.isEmpty
        let hasValidPoll = showPoll && pollOptions.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count >= 2
        return hasText || hasImages || hasMedia || hasValidPoll
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader
                editorContent
                bottomToolbar
            }
            .background(Color.nook.clubDetailBackground)
            .navigationBarHidden(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isBodyFocused = true
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $pickerSelection,
                maxSelectionCount: 10 - attachedImages.count,
                matching: .images
            )
            .onChange(of: pickerSelection) { _, newItems in
                guard !newItems.isEmpty else { return }
                appendImages(from: newItems)
                pickerSelection = []
            }
            .sheet(isPresented: $showMediaPicker) {
                AddMediaToPostSheet(selectedMedia: $attachedMedia, accent: accent)
            }
        }
    }

    private func appendImages(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if attachedImages.count < 10 {
                                attachedImages.append(uiImage)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Header

private extension ComposePostView {
    var sheetHeader: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .frame(width: 36, height: 36)
                    .background(Color.nook.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(clubName)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.clubDetailMeta)

            Spacer()

            Button {
                publishPost()
            } label: {
                Text("Post")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(canPost ? accent : accent.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canPost || isPosting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Editor Content

private extension ComposePostView {
    var editorContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(NookFont.labelSmall)
                            .foregroundStyle(Color.nook.clubDetailTitle)

                        Text("Posting to \(clubName)")
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ZStack(alignment: .topLeading) {
                    if postBody.isEmpty {
                        Text("What's on your mind?")
                            .font(NookFont.label)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                            .padding(.top, 20)
                            .padding(.leading, 20)
                            .onTapGesture {
                                isBodyFocused = true
                            }
                    }

                    TextEditor(text: $postBody)
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.clubDetailTitle)
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .focused($isBodyFocused)
                        .frame(minHeight: 160)
                        .padding(.horizontal, 15)
                        .padding(.top, 12)
                }

                if !attachedImages.isEmpty {
                    imageCarousel
                        .padding(.top, 8)
                }

                if !attachedMedia.isEmpty {
                    mediaCarousel
                        .padding(.top, 12)
                }

                if showPoll {
                    pollEditor
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Image Carousel

private extension ComposePostView {
    var imageCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, uiImage in
                    imageCard(uiImage, at: index)
                }

                if attachedImages.count < 10 {
                    addMoreButton
                }
            }
            .padding(.horizontal, 20)
        }
    }

    func imageCard(_ uiImage: UIImage, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(
                    width: attachedImages.count == 1 ? UIScreen.main.bounds.width - 40 : 220,
                    height: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    _ = attachedImages.remove(at: index)
                }
            } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    var addMoreButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            VStack(spacing: 8) {
                Image("plus-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text("Add")
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }
            .frame(width: 80, height: 200)
            .background(
                RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                    .strokeBorder(Color.nook.detailTabBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Attached Media Carousel

private extension ComposePostView {
    var mediaCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(attachedMedia) { item in
                    mediaCard(item)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    func mediaCard(_ item: MediaSearchResult) -> some View {
        let category = SearchMediaCategory.from(apiMediaType: item.mediaType)
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                MediaPosterImage(
                    url: item.imageURL,
                    width: 92,
                    height: 128,
                    fallbackColor: category?.dotColor.opacity(0.3) ?? Color.nook.searchShimmerBase
                )

                Text(item.title)
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineLimit(1)
                    .frame(width: 92, alignment: .leading)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    attachedMedia.removeAll { $0.id == item.id }
                }
            } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 11, height: 11)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

// MARK: - Toolbar helpers

private extension ComposePostView {
    func toolbarIconButton(_ icon: String, active: Bool, badge: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(active ? accent : Color.nook.clubDetailTitle)

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
            }
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Toolbar

private extension ComposePostView {
    var bottomToolbar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            HStack(spacing: 18) {
                // Photo
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image("image")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Color.nook.clubDetailTitle)

                        if !attachedImages.isEmpty {
                            Text("\(attachedImages.count)")
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.clubDetailMeta)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Poll
                toolbarIconButton("chart-bar", active: showPoll) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPoll.toggle()
                        if showPoll { pollOptions = ["", ""] }
                    }
                }

                // Attach media (movies/shows/anime…)
                toolbarIconButton("bookmark-simple", active: !attachedMedia.isEmpty, badge: attachedMedia.count) {
                    showMediaPicker = true
                }

                Spacer()

                if !postBody.isEmpty {
                    Text("\(postBody.count)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.nook.clubDetailBackground)
    }
}

// MARK: - Poll Editor

private extension ComposePostView {
    var pollEditor: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Poll")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.clubDetailTitle)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPoll = false
                    }
                } label: {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Options
            VStack(spacing: 10) {
                ForEach(Array(pollOptions.enumerated()), id: \.offset) { index, _ in
                    pollOptionField(index: index)
                }

                if pollOptions.count < 6 {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            pollOptions.append("")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image("plus-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)

                            Text("Add option")
                                .font(NookFont.labelMediumSmall)
                        }
                        .foregroundStyle(Color.nook.clubDetailMeta)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.nook.detailTabBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Polls always run for 1 day.
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text("Poll closes in 1 day")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                .fill(Color.nook.card)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                        .strokeBorder(Color.nook.clubDetailPostCardBorder, lineWidth: 1)
                )
        )
    }

    func pollOptionField(index: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .strokeBorder(Color.nook.detailTabBorder, lineWidth: 1.5)
                .frame(width: 18, height: 18)

            TextField(
                "Option \(index + 1)",
                text: $pollOptions[index]
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.clubDetailTitle)
            .focused($focusedPollOption, equals: index)

            if pollOptions.count > 2 {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        _ = pollOptions.remove(at: index)
                    }
                } label: {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.nook.secondary)
        )
    }
}

// MARK: - Actions

private extension ComposePostView {
    func publishPost() {
        guard canPost else { return }
        isPosting = true

        let trimmedBody = postBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = attachedImages
        let media = attachedMedia
        let pollDraft = buildPollDraft()

        Task {
            do {
                if let clubId {
                    let clubService = ClubService()
                    let mediaAPI = MediaAPIService()
                    let imageDatas = images.compactMap { $0.jpegData(compressionQuality: 0.8) }

                    // Resolve each picked media to its media_items row id (upserts via media-detail).
                    var mediaItemIds: [UUID] = []
                    for item in media {
                        if let detail = try? await mediaAPI.detail(source: item.source, sourceId: item.mediaId, mediaType: item.mediaType),
                           let dbId = detail.dbId {
                            mediaItemIds.append(dbId)
                        }
                    }

                    try await clubService.createPost(
                        clubId: clubId,
                        body: trimmedBody,
                        imageDatas: imageDatas,
                        mediaItemIds: mediaItemIds,
                        poll: pollDraft
                    )
                }

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                }
            }
        }
    }

    func buildPollDraft() -> ClubPollDraft? {
        guard showPoll else { return nil }
        let options = pollOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard options.count >= 2 else { return nil }
        return ClubPollDraft(options: options, closesAt: Date().addingTimeInterval(pollDurationSeconds))
    }
}

// MARK: - Add Media To Post Sheet

struct AddMediaToPostSheet: View {
    @Binding var selectedMedia: [MediaSearchResult]
    var accent: Color = Color.nook.primary
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool

    private static let maxSelection = 8

    private var selectedKeys: Set<String> {
        Set(selectedMedia.map(Self.key))
    }

    private static func key(_ item: MediaSearchResult) -> String {
        "\(item.source)|\(item.mediaId)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                ScrollView {
                    LazyVStack(spacing: 0) {
                        switch viewModel.searchState {
                        case .idle:
                            hint("Search for movies, shows, anime, games and more to attach.")
                        case .loading:
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                        case .noResults:
                            hint("No results for \"\(viewModel.searchText)\".")
                        case .results:
                            ForEach(viewModel.results) { item in
                                mediaRow(item)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.nook.searchBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Media")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(accent)
                }
            }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.search() }
            .onChange(of: viewModel.selectedFilter) { _, _ in
                if !viewModel.searchText.isEmpty { viewModel.search() }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isSearchFocused = true }
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.clubDetailMeta)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 60)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.searchBarPlaceholder)

            TextField(
                "Search media",
                text: $viewModel.searchText,
                prompt: Text("Search media")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.searchBarPlaceholder)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.searchBarText)
            .focused($isSearchFocused)
            .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nook.searchBarPlaceholder)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.nook.secondary))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func mediaRow(_ item: MediaSearchResult) -> some View {
        let isAdded = selectedKeys.contains(Self.key(item))
        let category = SearchMediaCategory.from(apiMediaType: item.mediaType)

        return HStack(spacing: 16) {
            MediaPosterImage(
                url: item.imageURL,
                width: 56,
                height: 72,
                fallbackColor: category?.dotColor.opacity(0.3) ?? Color.nook.searchShimmerBase
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let cat = category {
                        Text(cat.uppercaseLabel)
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(cat.dotColor)
                    }
                    if let year = item.year {
                        Circle().fill(Color.nook.searchSectionLabel).frame(width: 3, height: 3)
                        Text(year)
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(Color.nook.searchSectionLabel)
                    }
                }

                Text(item.title)
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.searchBarText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                toggle(item, isAdded: isAdded)
            } label: {
                Image(isAdded ? "check-bold" : "plus-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(isAdded ? .white : accent)
                    .frame(width: 36, height: 36)
                    .background(isAdded ? accent : Color.clear, in: Circle())
                    .overlay(Circle().strokeBorder(isAdded ? Color.clear : accent.opacity(0.5), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func toggle(_ item: MediaSearchResult, isAdded: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            if isAdded {
                selectedMedia.removeAll { Self.key($0) == Self.key(item) }
            } else if selectedMedia.count < Self.maxSelection {
                selectedMedia.append(item)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ComposePostView(clubName: "Anime Corner")
}
