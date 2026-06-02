import PhotosUI
import SwiftUI

// MARK: - Club Privacy

enum ClubPrivacy: CaseIterable {
    case publicOpen
    case privateHidden

    var label: String {
        switch self {
        case .publicOpen: "Public"
        case .privateHidden: "Private"
        }
    }

    var subtitle: String {
        switch self {
        case .publicOpen: "Anyone can find and join"
        case .privateHidden: "Only invited users can find and join"
        }
    }

    var icon: String {
        switch self {
        case .publicOpen: "lock-simple-open"
        case .privateHidden: "eye-slash-bold"
        }
    }
}

// MARK: - Banner Color Option

struct BannerColorOption: Identifiable, Equatable {
    let id = UUID()
    let color: Color
    let hex: UInt

    static func == (lhs: BannerColorOption, rhs: BannerColorOption) -> Bool {
        lhs.hex == rhs.hex
    }

    static let palette: [BannerColorOption] = [
        BannerColorOption(color: Color(hex: 0xBA68C8).opacity(0.3), hex: 0xBA68C8),
        BannerColorOption(color: Color(hex: 0xE57373).opacity(0.3), hex: 0xE57373),
        BannerColorOption(color: Color(hex: 0x64B5F6).opacity(0.3), hex: 0x64B5F6),
        BannerColorOption(color: Color(hex: 0xD4A373).opacity(0.3), hex: 0xD4A373),
        BannerColorOption(color: Color(hex: 0x66BB6A).opacity(0.3), hex: 0x66BB6A),
        BannerColorOption(color: Color(hex: 0xFFA726).opacity(0.3), hex: 0xFFA726),
        BannerColorOption(color: Color(hex: 0x7986CB).opacity(0.3), hex: 0x7986CB),
        BannerColorOption(color: Color(hex: 0x4DB6AC).opacity(0.3), hex: 0x4DB6AC),
        BannerColorOption(color: Color(hex: 0xF06292).opacity(0.3), hex: 0xF06292),
        BannerColorOption(color: Color(hex: 0x90A4AE).opacity(0.3), hex: 0x90A4AE),
    ]
}

// MARK: - Create Club Sheet

struct CreateClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var clubDescription = ""
    @State private var selectedCategories: Set<ClubCategory> = []
    @State private var selectedThemeColor: BannerColorOption = BannerColorOption.palette[0]
    @State private var privacy: ClubPrivacy = .publicOpen
    @State private var showPrivacyPicker = false
    @State private var isCreating = false
    @State private var similarClubs: [ClubItem] = []
    @State private var nameCheckTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    // Banner image
    @State private var bannerImage: UIImage?
    @State private var bannerPickerSelection: [PhotosPickerItem] = []
    @State private var showBannerPicker = false
    @State private var rawBannerImage: UIImage?
    @State private var showBannerCrop = false

    // Icon image
    @State private var iconImage: UIImage?
    @State private var iconPickerSelection: [PhotosPickerItem] = []
    @State private var showIconPicker = false
    @State private var rawIconImage: UIImage?
    @State private var showIconCrop = false

    private enum Field {
        case name, description
    }

    private var canCreate: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !selectedCategories.isEmpty
    }

    // Club detail banner: full-width × 192pt on ~393pt screen
    private let bannerCropAspect: CGFloat = 393.0 / 192.0
    // Club detail avatar: 80×80 square
    private let iconCropAspect: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    bannerSection
                        .padding(.top, 4)
                        .padding(.bottom, 24)

                    nameSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)

                    if !similarClubs.isEmpty {
                        duplicateWarning
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }

                    descriptionSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    themeColorSection
                        .padding(.bottom, 28)

                    categorySection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                    settingsCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.nook.createClubBackground)
        .sheet(isPresented: $showPrivacyPicker) {
            ClubSettingsPickerSheet(
                title: "Privacy",
                options: ClubPrivacy.allCases.map { ($0, $0.icon, $0.label, $0.subtitle) },
                selected: privacy
            ) { privacy = $0 }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.nook.createClubBackground)
        }
        .photosPicker(
            isPresented: $showBannerPicker,
            selection: $bannerPickerSelection,
            maxSelectionCount: 1,
            matching: .images
        )
        .photosPicker(
            isPresented: $showIconPicker,
            selection: $iconPickerSelection,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: bannerPickerSelection) { _, items in
            loadPickedBannerImage(items)
        }
        .onChange(of: iconPickerSelection) { _, items in
            loadPickedIconImage(items)
        }
        .fullScreenCover(isPresented: $showBannerCrop) {
            if let rawBannerImage {
                ImageCropView(image: rawBannerImage, cropAspect: bannerCropAspect) { cropped in
                    withAnimation(.easeOut(duration: 0.2)) {
                        bannerImage = cropped
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showIconCrop) {
            if let rawIconImage {
                ImageCropView(image: rawIconImage, cropAspect: iconCropAspect, cropShape: .roundedRect(cornerRadius: 22)) { cropped in
                    withAnimation(.easeOut(duration: 0.2)) {
                        iconImage = cropped
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

    // MARK: - Picker Helpers

    private func loadPickedBannerImage(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        bannerPickerSelection = []
        Task.detached {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let downsized = Self.downsample(data: data, maxWidth: 2000)
            await MainActor.run {
                rawBannerImage = downsized
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showBannerCrop = true
                }
            }
        }
    }

    private func loadPickedIconImage(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        iconPickerSelection = []
        Task.detached {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let downsized = Self.downsample(data: data, maxWidth: 2000)
            await MainActor.run {
                rawIconImage = downsized
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showIconCrop = true
                }
            }
        }
    }

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

    // MARK: - Header

    private var sheetHeader: some View {
        ZStack {
            Text("New Club")
                .font(.custom("PlusJakartaSans-Bold", size: 18))
                .foregroundStyle(Color.nook.createClubTitle)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.createClubTitle)
                        .frame(width: 36, height: 36)
                        .background(Color.nook.createClubFieldBackground, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    createClub()
                } label: {
                    Text("Create")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(canCreate ? Color.nook.createClubButton : Color.nook.createClubButton.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate || isCreating)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Banner + Icon

    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            Button {
                showBannerPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let bannerImage {
                        Image(uiImage: bannerImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(bannerCropAspect, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.nook.createClubBorder, lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(selectedThemeColor.color)
                            .aspectRatio(bannerCropAspect, contentMode: .fit)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.nook.createClubBorder, lineWidth: 1)
                            )
                            .overlay {
                                Image("image")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                    }

                    HStack(spacing: 6) {
                        Image("image")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .foregroundStyle(Color.nook.createClubTitle)

                        Text(bannerImage == nil ? "Add Banner" : "Change")
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.createClubTitle)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(.white.opacity(0.9), in: Capsule())
                    .padding(10)
                }
            }
            .buttonStyle(.plain)

            // Club icon overlapping the bottom-left of the banner
            Button {
                showIconPicker = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.nook.createClubBackground)
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    if let iconImage {
                        Image(uiImage: iconImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedThemeColor.color.opacity(1.5))
                            .frame(width: 68, height: 68)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.nook.createClubBorder, lineWidth: 1)
                            )
                            .overlay {
                                VStack(spacing: 4) {
                                    Image("camera-bold")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(.white.opacity(0.6))

                                    Text("Icon")
                                        .font(NookFont.captionBold)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                    }
                }
            }
            .buttonStyle(.plain)
            .offset(x: 16, y: 28)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Theme Color

    private var themeColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme Color")
                .font(NookFont.labelLarge)
                .foregroundStyle(Color.nook.createClubTitle)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BannerColorOption.palette) { option in
                        let isSelected = selectedThemeColor == option

                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedThemeColor = option
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 32, height: 32)
                                .padding(4)
                                .background(
                                    Circle()
                                        .strokeBorder(
                                            isSelected
                                                ? Color(hex: option.hex)
                                                : Color.clear,
                                            lineWidth: 2.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "Name your club...",
                text: $name,
                prompt: Text("Name your club...")
                    .font(.custom("PlusJakartaSans-Bold", size: 24))
                    .foregroundStyle(Color.nook.createClubTitle.opacity(0.25))
            )
            .font(.custom("PlusJakartaSans-Bold", size: 24))
            .foregroundStyle(Color.nook.createClubTitle)
            .focused($focusedField, equals: .name)
            .padding(.top, 36)
            .padding(.bottom, 16)
            .onChange(of: name) { _, newValue in
                checkForDuplicates(newValue)
            }

            Rectangle()
                .fill(Color.nook.createClubBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Duplicate Warning

    private var duplicateWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("warning-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.createClubWarningIcon)

                Text("Similar clubs already exist")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.createClubWarningText)
            }

            VStack(spacing: 6) {
                ForEach(similarClubs) { club in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(club.bannerColor)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image("users-three-bold")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.white.opacity(0.5))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(club.name)
                                .font(NookFont.labelSmall)
                                .foregroundStyle(Color.nook.createClubTitle)
                                .lineLimit(1)

                            Text(club.memberCount)
                                .font(NookFont.caption)
                                .foregroundStyle(Color.nook.createClubMeta)
                        }

                        Spacer()

                        Text("View")
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.createClubButton)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.nook.createClubWarningBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.nook.createClubWarningBorder, lineWidth: 1)
                    )
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.nook.createClubWarningBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.nook.createClubWarningBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Description

    private var descriptionSection: some View {
        ZStack(alignment: .topLeading) {
            if clubDescription.isEmpty {
                Text("What's this club about?")
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color.nook.createClubMeta)
                    .padding(.top, 14)
                    .onTapGesture { focusedField = .description }
            }

            TextEditor(text: $clubDescription)
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.createClubTitle)
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .description)
                .frame(minHeight: 80)
                .padding(.leading, -5)
                .padding(.top, 6)
        }
    }

    // MARK: - Category (multi-select with onboarding-style icons)

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categories")
                    .font(NookFont.labelLarge)
                    .foregroundStyle(Color.nook.createClubTitle)

                Spacer()

                if !selectedCategories.isEmpty {
                    Text("\(selectedCategories.count) selected")
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.createClubMeta)
                }
            }

            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ClubCategory.allCases) { category in
                    let isSelected = selectedCategories.contains(category)

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if isSelected {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                                generator.impactOccurred()
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(category.iconBackgroundColor)
                                    .frame(width: 44, height: 44)

                                Image(category.iconName)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(category.iconColor)
                            }

                            Text(category.label)
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.createClubTitle)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? Color.nook.createClubButton
                                        : Color.nook.createClubBorder,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .overlay(alignment: .topTrailing) {
                            if isSelected {
                                ZStack {
                                    Circle()
                                        .fill(Color.nook.createClubButton)
                                        .frame(width: 20, height: 20)

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(8)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.nook.createClubBorder, lineWidth: 1)
        )
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.nook.createClubButton)
                .frame(width: 36, height: 36)
                .background(
                    Color.nook.createClubFieldBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.createClubTitle)

                Text(subtitle)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.createClubMeta)
            }

            Spacer()

            Image("caret-left-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.nook.createClubMeta)
                .rotationEffect(.degrees(180))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }

    // MARK: - Duplicate Detection

    private func checkForDuplicates(_ text: String) {
        nameCheckTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 3 else {
            withAnimation(.easeOut(duration: 0.2)) {
                similarClubs = []
            }
            return
        }

        nameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            let lowerQuery = trimmed.lowercased()
            let matches = ClubsView.mockClubs.filter { club in
                club.name.lowercased().contains(lowerQuery) ||
                lowerQuery.contains(club.name.lowercased().prefix(4))
            }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    similarClubs = Array(matches.prefix(2))
                }
            }
        }
    }

    // MARK: - Create

    private func createClub() {
        guard canCreate else { return }
        isCreating = true

        Task {
            do {
                let clubService = ClubService()

                let privacyValue: String = switch privacy {
                case .publicOpen: "public"
                case .privateHidden: "members_only"
                }

                let categoryValue = selectedCategories.first?.id ?? "mixed"

                let bannerData = bannerImage?.jpegData(compressionQuality: 0.8)
                let iconData = iconImage?.jpegData(compressionQuality: 0.8)

                _ = try await clubService.createClub(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: clubDescription.isEmpty ? nil : clubDescription,
                    category: categoryValue,
                    privacy: privacyValue,
                    bannerData: bannerData,
                    iconData: iconData
                )

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}


// MARK: - Club Settings Picker Sheet

private struct ClubSettingsPickerSheet<T: Equatable>: View {
    let title: String
    let options: [(value: T, icon: String, label: String, subtitle: String)]
    let selected: T
    var onSelect: (T) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.createClubTitle)
                .padding(.top, 20)
                .padding(.bottom, 20)

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
                                .foregroundStyle(Color.nook.createClubButton)
                                .frame(width: 36, height: 36)
                                .background(
                                    Color.nook.createClubFieldBackground,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                    .font(NookFont.labelBoldSmall)
                                    .foregroundStyle(Color.nook.createClubTitle)

                                Text(option.subtitle)
                                    .font(NookFont.caption)
                                    .foregroundStyle(Color.nook.createClubMeta)
                            }

                            Spacer()

                            if option.value == selected {
                                Image("check-bold")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(Color.nook.createClubButton)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < options.count - 1 {
                        Rectangle()
                            .fill(Color.nook.createClubBorder.opacity(0.5))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.nook.createClubBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    CreateClubSheet()
}
