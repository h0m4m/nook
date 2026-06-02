import PhotosUI
import SwiftUI

struct EditNookSheet: View {
    let nook: NookItem
    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var nookDescription: String
    @State private var privacy: NookPrivacy
    @State private var coverImage: UIImage?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var rawPickedImage: UIImage?
    @State private var showCropSheet = false
    @State private var showPrivacyPicker = false
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, description }

    private let coverRadius: CGFloat = 32
    private let settingsRadius: CGFloat = 24

    init(nook: NookItem, onSaved: @escaping () -> Void = {}, onDeleted: @escaping () -> Void = {}) {
        self.nook = nook
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        self._name = State(initialValue: nook.title)
        self._nookDescription = State(initialValue: nook.description)
        self._privacy = State(initialValue: NookPrivacy.from(dbValue: nook.privacy))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

                    settingsCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    deleteButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(hex: 0xFDFBF9))
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
                let downsized = Self.downsample(data: data, maxWidth: 2000)
                await MainActor.run {
                    rawPickedImage = downsized
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
                    cropAspect: 402.0 / 394.0
                ) { cropped in
                    withAnimation(.easeOut(duration: 0.2)) {
                        coverImage = cropped
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this nook?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the nook and all its items. This can't be undone.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        ZStack {
            Text("Edit Nook")
                .font(.custom("PlusJakartaSans-Bold", size: 18))
                .foregroundStyle(Color(hex: 0x1C1918))

            HStack {
                Button { dismiss() } label: {
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

                Button { save() } label: {
                    Text("Save")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(canSave ? Color(hex: 0x43313D) : Color(hex: 0x43313D).opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)
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
                coverContent

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

    @ViewBuilder
    private var coverContent: some View {
        if let coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
                )
        } else if let url = nook.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color(hex: 0xF2EFEE).opacity(0.3)
                }
            }
            .aspectRatio(402.0 / 394.0, contentMode: .fill)
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

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Button { showPrivacyPicker = true } label: {
                settingsRow(icon: privacy.icon, title: "Privacy", subtitle: privacy.subtitle)
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

    // MARK: - Delete

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image("trash")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                Text("Delete Nook")
                    .font(NookFont.labelBoldSmall)
            }
            .foregroundStyle(Color.nook.clubDetailLikeActive)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.nook.clubDetailLikeActive.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    // MARK: - Actions

    private func save() {
        guard canSave, let dbId = nook.dbId else { return }
        isSaving = true

        Task {
            let service = NookService()

            var coverUrl: String?
            if let coverImage, let data = coverImage.jpegData(compressionQuality: 0.8) {
                coverUrl = try? await service.uploadCover(data: data)
            }

            try? await service.updateNook(
                nookId: dbId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: nookDescription,
                privacy: privacy.dbValue,
                coverUrl: coverUrl
            )

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            await MainActor.run {
                NotificationCenter.default.post(name: .nooksDidChange, object: nil)
                onSaved()
                dismiss()
            }
        }
    }

    private func performDelete() {
        guard let dbId = nook.dbId else { return }
        isSaving = true

        Task {
            let service = NookService()
            try? await service.deleteNook(nookId: dbId)

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            await MainActor.run {
                NotificationCenter.default.post(name: .nooksDidChange, object: nil)
                dismiss()
                onDeleted()
            }
        }
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
}
