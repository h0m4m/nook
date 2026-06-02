import PhotosUI
import SwiftUI

struct CreateNookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var nookDescription = ""
    @State private var coverImage: UIImage?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var rawPickedImage: UIImage?
    @State private var showCropSheet = false
    @State private var mediaItems: [MediaSearchResult] = []
    @State private var mediaNotes: [UUID: String] = [:]
    @State private var showAddMedia = false
    @State private var editingNoteItem: MediaSearchResult?
    @State private var editingNoteText = ""
    @State private var privacy: NookPrivacy = .publicVisible
    @State private var showPrivacyPicker = false
    @State private var isPublishing = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, description
    }

    private var canPublish: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !nookDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && mediaItems.count >= 2
    }

    private let coverRadius: CGFloat = 32
    private let cardRadius: CGFloat = 24
    private let settingsRadius: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    coverSection
                        .padding(.top, 4)
                        .padding(.bottom, 24)

                    titleSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    descriptionSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    itemsSection
                        .padding(.bottom, 28)

                    settingsCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(hex: 0xFDFBF9))
        .sheet(isPresented: $showAddMedia) {
            AddMediaToNookSheet(mediaItems: $mediaItems)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.nook.searchBackground)
        }
        .sheet(item: $editingNoteItem) { item in
            MediaNoteSheet(
                mediaTitle: item.title,
                note: editingNoteText,
                onSave: { note in
                    if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        mediaNotes.removeValue(forKey: item.id)
                    } else {
                        mediaNotes[item.id] = note
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: 0xFDFBF9))
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickerSelection,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: pickerSelection) { _, items in
            guard let item = items.first else { return }
            pickerSelection = []
            Task.detached {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                // Downsample to max 2000px wide to avoid UI freezes with huge photos
                let downsized = Self.downsample(data: data, maxWidth: 2000)
                await MainActor.run {
                    rawPickedImage = downsized
                    // Small delay so the picker dismissal animation completes first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCropSheet = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCropSheet) {
            if let rawPickedImage {
                ImageCropView(
                    image: rawPickedImage,
                    cropAspect: 393.0 / 192.0
                ) { cropped in
                    withAnimation(.easeOut(duration: 0.2)) {
                        coverImage = cropped
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .name
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        ZStack {
            Text("New Nook")
                .font(.custom("PlusJakartaSans-Bold", size: 18))
                .foregroundStyle(Color(hex: 0x1C1918))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color(hex: 0x1C1918))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: 0xF2EFEE), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    publishNook()
                } label: {
                    Text("Publish")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(canPublish ? Color(hex: 0x43313D) : Color(hex: 0x43313D).opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canPublish || isPublishing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Cover

    private var coverSection: some View {
        Button {
            showPhotoPicker = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .fill(Color(hex: 0xF2EFEE).opacity(0.3))
                        .aspectRatio(393.0 / 192.0, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
                        )
                        .overlay {
                            Image("image")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .foregroundStyle(Color(hex: 0x78716C).opacity(0.4))
                        }
                }

                HStack(spacing: 6) {
                    Image("palette")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color(hex: 0x1C1918))

                    Text("Change Cover")
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color(hex: 0x1C1918))
                }
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(.white.opacity(0.9), in: Capsule())
                .padding(12)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "Give your Nook a title...",
                text: $name,
                prompt: Text("Give your Nook a title...")
                    .font(.custom("PlusJakartaSans-Bold", size: 24))
                    .foregroundStyle(Color(hex: 0x1C1918).opacity(0.25))
            )
            .font(.custom("PlusJakartaSans-Bold", size: 24))
            .foregroundStyle(Color(hex: 0x1C1918))
            .focused($focusedField, equals: .name)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color(hex: 0xE6E2E0))
                .frame(height: 1)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        ZStack(alignment: .topLeading) {
            if nookDescription.isEmpty {
                Text("Write a description or an essay about this collection...")
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color(hex: 0x78716C))
                    .padding(.top, 14)
                    .onTapGesture { focusedField = .description }
            }

            TextEditor(text: $nookDescription)
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color(hex: 0x1C1918))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .description)
                .frame(minHeight: 80)
                .padding(.leading, -5)
                .padding(.top, 6)
        }
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("The Items")
                    .font(NookFont.labelLarge)
                    .foregroundStyle(Color(hex: 0x1C1918))

                Spacer()

                if !mediaItems.isEmpty {
                    Text("\(mediaItems.count) item\(mediaItems.count == 1 ? "" : "s") selected")
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color(hex: 0x78716C))
                }
            }
            .padding(.horizontal, 24)

            if mediaItems.isEmpty {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    addMediaGridCard
                }
                .padding(.horizontal, 24)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                        mediaCard(item, at: index)
                    }
                }
                .padding(.horizontal, 24)

                if mediaItems.count < 10 {
                    addMediaInlineButton
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var addMediaGridCard: some View {
        Button {
            showAddMedia = true
        } label: {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(Color(hex: 0xF2EFEE).opacity(0.3))
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                            .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1.5)
                    )
                    .overlay {
                        VStack(spacing: 8) {
                            Image("plus-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Color(hex: 0x43313D))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: 0x43313D).opacity(0.1), in: Circle())

                            Text("Add Media")
                                .font(NookFont.labelBoldSmall)
                                .foregroundStyle(Color(hex: 0x1C1918))
                        }
                    }

                Spacer().frame(height: 24)
            }
        }
        .buttonStyle(.plain)
    }

    private var addMediaInlineButton: some View {
        Button {
            showAddMedia = true
        } label: {
            HStack(spacing: 8) {
                Image("plus-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                Text("Add Media")
                    .font(NookFont.labelBoldSmall)
            }
            .foregroundStyle(Color(hex: 0x43313D))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func mediaCard(_ item: MediaSearchResult, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                MediaPosterImage(
                    url: item.imageURL,
                    width: geo.size.width,
                    height: geo.size.height,
                    cornerRadius: cardRadius,
                    fallbackColor: SearchMediaCategory.from(apiMediaType: item.mediaType)?.dotColor.opacity(0.3) ?? Color.nook.searchShimmerBase
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
                )
                // Remove button
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            _ = mediaItems.remove(at: index)
                            mediaNotes.removeValue(forKey: item.id)
                        }
                    } label: {
                        Image("x-bold")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
                .onTapGesture {
                    editingNoteText = mediaNotes[item.id] ?? ""
                    editingNoteItem = item
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color(hex: 0x1C1918))
                    .lineLimit(1)

                if let note = mediaNotes[item.id] {
                    Text(note)
                        .font(NookFont.caption)
                        .foregroundStyle(Color(hex: 0x78716C))
                        .lineLimit(1)
                } else {
                    Button {
                        editingNoteText = ""
                        editingNoteItem = item
                    } label: {
                        Text("Add a note")
                            .font(NookFont.caption)
                            .foregroundStyle(Color(hex: 0x78716C).opacity(0.6))
                            .italic()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Button { showPrivacyPicker = true } label: {
                settingsRow(
                    icon: privacy.icon,
                    title: "Privacy",
                    subtitle: privacy.subtitle
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: settingsRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: settingsRadius, style: .continuous)
                .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
        )
        .sheet(isPresented: $showPrivacyPicker) {
            NookSettingsPickerSheet(
                title: "Privacy",
                options: NookPrivacy.allCases.map { ($0, $0.icon, $0.label, $0.subtitle) },
                selected: privacy
            ) { privacy = $0 }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: 0xFDFBF9))
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color(hex: 0x43313D))
                .frame(width: 36, height: 36)
                .background(Color(hex: 0xF2EFEE), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color(hex: 0x1C1918))

                Text(subtitle)
                    .font(NookFont.caption)
                    .foregroundStyle(Color(hex: 0x78716C))
            }

            Spacer()

            Image("caret-left-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color(hex: 0x78716C))
                .rotationEffect(.degrees(180))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }

    // MARK: - Image Helpers

    nonisolated private static func downsample(data: Data, maxWidth: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxWidth,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Publish

    private func publishNook() {
        guard canPublish else { return }
        isPublishing = true

        Task {
            do {
                let nookService = NookService()

                let coverData = coverImage?.jpegData(compressionQuality: 0.8)

                let nookId = try await nookService.createNook(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: nookDescription.isEmpty ? nil : nookDescription,
                    coverData: coverData,
                    privacy: privacy.dbValue
                )

                // Add media items — resolve dbIds by fetching detail for each
                if !mediaItems.isEmpty {
                    let mediaAPI = MediaAPIService()
                    var nookItemsToInsert: [(mediaItemId: UUID, note: String?, sortOrder: Int)] = []

                    for (index, item) in mediaItems.enumerated() {
                        // Fetch detail to ensure media_item exists and get dbId
                        if let detail = try? await mediaAPI.detail(
                            source: item.source,
                            sourceId: item.mediaId,
                            mediaType: item.mediaType
                        ), let dbId = detail.dbId {
                            nookItemsToInsert.append((
                                mediaItemId: dbId,
                                note: mediaNotes[item.id],
                                sortOrder: index
                            ))
                        }
                    }

                    if !nookItemsToInsert.isEmpty {
                        try? await nookService.addItems(nookId: nookId, items: nookItemsToInsert)
                    }
                }

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                await MainActor.run {
                    NotificationCenter.default.post(name: .nooksDidChange, object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                }
            }
        }
    }
}

// MARK: - Media Note Sheet

private struct MediaNoteSheet: View {
    let mediaTitle: String
    @State var note: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text(mediaTitle)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color(hex: 0x1C1918))
                    .lineLimit(1)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color(hex: 0x78716C))

                    Spacer()

                    Button("Save") {
                        onSave(note)
                        dismiss()
                    }
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color(hex: 0x43313D))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Text editor
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Add a note about this item...")
                        .font(NookFont.bodyMedium)
                        .foregroundStyle(Color(hex: 0x78716C))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .onTapGesture { isFocused = true }
                }

                TextEditor(text: $note)
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color(hex: 0x1C1918))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, 15)
                    .padding(.top, -4)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}

// MARK: - Add Media Sub-Sheet

private struct AddMediaToNookSheet: View {
    @Binding var mediaItems: [MediaSearchResult]
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @State private var userInterests: [SearchMediaCategory] = []
    @State private var recentLibrary: [MediaSearchResult] = []
    @FocusState private var isSearchFocused: Bool

    private var addedIDs: Set<UUID> {
        Set(mediaItems.map(\.id))
    }

    var body: some View {
        NavigationStack {
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
                    Text("Add Media")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(Color.nook.detailTitle)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.detailTabActive)
                }
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
        .task {
            await loadUserInterests()
            await loadRecentLibrary()
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

    @ViewBuilder
    private var idleContent: some View {
        if recentLibrary.isEmpty {
            SearchEmptyState(
                icon: "magnifying-glass-bold",
                title: "Search to add media",
                subtitle: "Find movies, shows, anime, books, and manga to add to your nook"
            )
        } else {
            HStack(spacing: 0) {
                sectionHeader("RECENTLY IN YOUR LIBRARY")
                Spacer()
            }

            ForEach(Array(recentLibrary.enumerated()), id: \.element.id) { index, item in
                nookMediaRow(item)
                    .padding(.horizontal, 24)

                if index < recentLibrary.count - 1 {
                    Spacer().frame(height: 24)
                }
            }
        }
    }

    private func loadRecentLibrary() async {
        guard let userId = try? await supabase.auth.session.user.id else { return }
        guard let items = try? await TrackingService().getLibrary(userId: userId) else { return }
        recentLibrary = items
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20)
            .map {
                MediaSearchResult(
                    mediaId: $0.sourceId,
                    source: $0.source,
                    mediaType: $0.mediaType,
                    title: $0.title,
                    imageURL: $0.imageURL,
                    year: $0.year,
                    score: $0.score
                )
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
            let results = viewModel.results

            HStack(spacing: 0) {
                sectionHeader("\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                Spacer()
            }

            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                nookMediaRow(item)
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

    // MARK: - Media Row

    private func nookMediaRow(_ item: MediaSearchResult) -> some View {
        let isAdded = addedIDs.contains(item.id)
        let category = SearchMediaCategory.from(apiMediaType: item.mediaType)

        return HStack(spacing: 16) {
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

            nookAddButton(for: item, isAdded: isAdded)
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private func nookAddButton(for item: MediaSearchResult, isAdded: Bool) -> some View {
        if #available(iOS 26, *) {
            Button {
                toggleItem(item, isAdded: isAdded)
            } label: {
                addButtonIcon(isAdded: isAdded)
                    .foregroundStyle(isAdded ? .white : .primary)
                    .frame(width: 40, height: 40)
                    .background(
                        isAdded ? Color.nook.searchAddedButton : .white,
                        in: Circle()
                    )
                    .glassEffect(
                        isAdded ? .regular : .regular.interactive(),
                        in: .circle
                    )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                toggleItem(item, isAdded: isAdded)
            } label: {
                Circle()
                    .fill(isAdded ? Color.nook.searchAddedButton : Color.nook.searchAddButton)
                    .frame(width: 40, height: 40)
                    .overlay {
                        addButtonIcon(isAdded: isAdded)
                            .foregroundStyle(isAdded ? .white : Color.nook.searchAddedButton)
                    }
                    .shadow(
                        color: isAdded ? .black.opacity(0.1) : .clear,
                        radius: 3, x: 0, y: 2
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func addButtonIcon(isAdded: Bool) -> some View {
        Group {
            if isAdded {
                Image("check-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            } else {
                Image("plus-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            }
        }
    }

    private func toggleItem(_ item: MediaSearchResult, isAdded: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if isAdded {
                mediaItems.removeAll { $0.id == item.id }
            } else if mediaItems.count < 10 {
                mediaItems.append(item)
            }
        }

        generator.impactOccurred()
    }

    // MARK: - Shared

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(NookFont.tabLabel)
            .tracking(1)
            .foregroundStyle(Color.nook.searchSectionLabel)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
    }

    // MARK: - Load Interests

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
