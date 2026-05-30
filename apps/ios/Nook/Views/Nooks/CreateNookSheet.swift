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
    @State private var layout: NookLayout = .grid
    @State private var showPrivacyPicker = false
    @State private var showLayoutPicker = false
    @State private var isPublishing = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, description
    }

    enum NookPrivacy: CaseIterable {
        case publicVisible
        case friendsOnly
        case privateOnly

        var label: String {
            switch self {
            case .publicVisible: "Public"
            case .friendsOnly: "Friends Only"
            case .privateOnly: "Only Me"
            }
        }

        var subtitle: String {
            switch self {
            case .publicVisible: "Visible to everyone"
            case .friendsOnly: "Only friends can see"
            case .privateOnly: "Only you can see"
            }
        }

        var icon: String {
            switch self {
            case .publicVisible: "lock-simple-open"
            case .friendsOnly: "users-bold"
            case .privateOnly: "eye-slash-bold"
            }
        }
    }

    enum NookLayout: CaseIterable {
        case grid
        case list

        var label: String {
            switch self {
            case .grid: "Grid View"
            case .list: "List View"
            }
        }

        var subtitle: String {
            switch self {
            case .grid: "Show items as a poster grid"
            case .list: "Show items as a detailed list"
            }
        }
    }

    private var canPublish: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCropSheet = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCropSheet) {
            if let rawPickedImage {
                CoverCropView(image: rawPickedImage) { cropped in
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
                        .aspectRatio(402.0 / 394.0, contentMode: .fit)
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
            } else if layout == .grid {
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
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                        mediaListRow(item, at: index)

                        if index < mediaItems.count - 1 {
                            Rectangle()
                                .fill(Color(hex: 0xE6E2E0))
                                .frame(height: 1)
                                .padding(.leading, 88)
                                .padding(.trailing, 24)
                        }
                    }
                }

                if mediaItems.count < 10 {
                    addMediaInlineButton
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
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

    private func mediaListRow(_ item: MediaSearchResult, at index: Int) -> some View {
        let category = SearchMediaCategory.from(apiMediaType: item.mediaType)

        return HStack(spacing: 14) {
            MediaPosterImage(
                url: item.imageURL,
                width: 48,
                height: 64,
                cornerRadius: 12,
                fallbackColor: category?.dotColor.opacity(0.3) ?? Color.nook.searchShimmerBase
            )
            .shadow(color: .black.opacity(0.08), radius: 1.5, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if let cat = category {
                        Text(cat.uppercaseLabel)
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(cat.dotColor)
                    }

                    if item.year != nil {
                        Circle()
                            .fill(Color(hex: 0x78716C))
                            .frame(width: 3, height: 3)

                        Text(item.year ?? "")
                            .font(NookFont.tabLabel)
                            .tracking(0.5)
                            .foregroundStyle(Color(hex: 0x78716C))
                    }
                }

                Text(item.title)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color(hex: 0x1C1918))
                    .lineLimit(1)

                if let note = mediaNotes[item.id] {
                    Text(note)
                        .font(NookFont.caption)
                        .foregroundStyle(Color(hex: 0x78716C))
                        .lineLimit(1)
                } else {
                    Text("Add a note")
                        .font(NookFont.caption)
                        .foregroundStyle(Color(hex: 0x78716C).opacity(0.6))
                        .italic()
                }
            }

            Spacer(minLength: 8)

            // Remove
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
                    .foregroundStyle(Color(hex: 0x78716C))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: 0xF2EFEE), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            editingNoteText = mediaNotes[item.id] ?? ""
            editingNoteItem = item
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

            Rectangle()
                .fill(Color(hex: 0xE6E2E0).opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 20)

            Button { showLayoutPicker = true } label: {
                settingsRow(
                    icon: "layout",
                    title: "Layout",
                    subtitle: layout.label
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
            SettingsPickerSheet(
                title: "Privacy",
                options: NookPrivacy.allCases.map { ($0, $0.icon, $0.label, $0.subtitle) },
                selected: privacy
            ) { privacy = $0 }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: 0xFDFBF9))
        }
        .sheet(isPresented: $showLayoutPicker) {
            SettingsPickerSheet(
                title: "Layout",
                options: NookLayout.allCases.map { ($0, "layout", $0.label, $0.subtitle) },
                selected: layout
            ) { layout = $0 }
            .presentationDetents([.height(280)])
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

                let privacyValue: String = switch privacy {
                case .publicVisible: "public"
                case .friendsOnly: "friends_only"
                case .privateOnly: "private"
                }

                let layoutValue: String = switch layout {
                case .grid: "grid"
                case .list: "list"
                }

                let coverData = coverImage?.jpegData(compressionQuality: 0.8)

                let nookId = try await nookService.createNook(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: nookDescription.isEmpty ? nil : nookDescription,
                    coverData: coverData,
                    privacy: privacyValue,
                    layout: layoutValue
                )

                // Add media items if any were added
                // Note: mediaItems are SearchResultItem which don't have dbId yet
                // This will be fully wired when media items have persistent IDs

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                await MainActor.run {
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

// MARK: - Settings Picker Sheet

private struct SettingsPickerSheet<T: Equatable>: View {
    let title: String
    let options: [(value: T, icon: String, label: String, subtitle: String)]
    let selected: T
    var onSelect: (T) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color(hex: 0x1C1918))
                .padding(.top, 20)
                .padding(.bottom, 20)

            // Options
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        onSelect(option.value)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(option.icon)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color(hex: 0x43313D))
                                .frame(width: 36, height: 36)
                                .background(
                                    Color(hex: 0xF2EFEE),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                    .font(NookFont.labelBoldSmall)
                                    .foregroundStyle(Color(hex: 0x1C1918))

                                Text(option.subtitle)
                                    .font(NookFont.caption)
                                    .foregroundStyle(Color(hex: 0x78716C))
                            }

                            Spacer()

                            if option.value == selected {
                                Image("check-bold")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(Color(hex: 0x43313D))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < options.count - 1 {
                        Rectangle()
                            .fill(Color(hex: 0xE6E2E0).opacity(0.5))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Cover Crop View

private struct CoverCropView: View {
    let image: UIImage
    var onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero

    // Match the detail hero ratio (full width × 394pt on ~393pt screen)
    private let cropAspect: CGFloat = 402.0 / 394.0

    private var cropWidth: CGFloat { max(1, viewSize.width - 48) }
    private var cropHeight: CGFloat { cropWidth / cropAspect }

    // Base size: image scaled to just fill the crop rect (scaledToFill the crop window)
    private var baseFitSize: CGSize {
        let imgAspect = image.size.width / image.size.height
        let cropAsp = cropWidth / cropHeight
        if imgAspect > cropAsp {
            // Image wider than crop — match heights
            let h = cropHeight
            let w = h * imgAspect
            return CGSize(width: w, height: h)
        } else {
            // Image taller than crop — match widths
            let w = cropWidth
            let h = w / imgAspect
            return CGSize(width: w, height: h)
        }
    }

    private func clampedOffset(for currentScale: CGFloat) -> CGSize {
        let fit = baseFitSize
        let displayW = fit.width * currentScale
        let displayH = fit.height * currentScale

        // Max offset so image edge doesn't go past crop edge
        let maxX = max(0, (displayW - cropWidth) / 2)
        let maxY = max(0, (displayH - cropHeight) / 2)

        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let fit = baseFitSize

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: fit.width, height: fit.height)
                        .scaleEffect(scale)
                        .offset(clampedOffset(for: scale))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = clampedOffset(for: scale)
                                    }
                                    lastOffset = clampedOffset(for: scale)
                                }
                        )
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value.magnification)
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        scale = max(1.0, scale)
                                        offset = clampedOffset(for: scale)
                                    }
                                    lastScale = scale
                                    lastOffset = clampedOffset(for: scale)
                                }
                        )

                    // Crop overlay
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .reverseMask {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .frame(width: cropWidth, height: cropHeight)
                        }
                        .allowsHitTesting(false)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                        .frame(width: cropWidth, height: cropHeight)
                        .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, newSize in viewSize = newSize }
            }

            // Toolbar
            VStack {
                Spacer()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)

                    Spacer()

                    Button("Done") {
                        performCrop()
                    }
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 40)
                    .background(.white.opacity(0.2), in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private func performCrop() {
        let fit = baseFitSize
        let clamped = clampedOffset(for: scale)

        guard fit.width > 0, fit.height > 0 else {
            onCrop(image)
            dismiss()
            return
        }

        // Pixels per point at base fit size
        let pppX = image.size.width / fit.width
        let pppY = image.size.height / fit.height

        // Crop center in image pixels
        let centerX = (image.size.width / 2) - (clamped.width / scale) * pppX
        let centerY = (image.size.height / 2) - (clamped.height / scale) * pppY

        // Crop size in image pixels
        let w = (cropWidth / scale) * pppX
        let h = (cropHeight / scale) * pppY

        var rect = CGRect(x: centerX - w / 2, y: centerY - h / 2, width: w, height: h)
        rect = rect.intersection(CGRect(origin: .zero, size: image.size))

        guard !rect.isEmpty, let cgImage = image.cgImage?.cropping(to: rect) else {
            onCrop(image)
            dismiss()
            return
        }

        onCrop(UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation))
        dismiss()
    }
}

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
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
            title: "Search to add media",
            subtitle: "Find movies, shows, anime, books, and manga to add to your nook"
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
