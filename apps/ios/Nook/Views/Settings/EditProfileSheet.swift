import PhotosUI
import Supabase
import SwiftUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() async -> Void)?

    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var avatarURL: URL?
    @State private var avatarImage: UIImage?
    @State private var cropRequest: CropRequest?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var usernameError: String?
    @State private var usernameCheckTask: Task<Void, Never>?
    @State private var originalUsername = ""
    @State private var usernameChangedAt: Date?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, username, bio
    }

    private var hasChanges: Bool {
        !displayName.isEmpty || !username.isEmpty || !bio.isEmpty || avatarImage != nil
    }

    private var usernameCooldownActive: Bool {
        guard let changedAt = usernameChangedAt else { return false }
        return changedAt.addingTimeInterval(14 * 24 * 60 * 60) > Date()
    }

    private var usernameCooldownEndDate: Date? {
        usernameChangedAt?.addingTimeInterval(14 * 24 * 60 * 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    avatarSection
                    fieldsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(NookFont.bodySmall)
                            .foregroundStyle(Color.nook.settingsDestructiveText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.nook.settingsBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Profile")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.settingsRowLabel)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.settingsRowSubtitle)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(Color.nook.settingsRowIcon)
                        } else {
                            Text("Save")
                                .font(NookFont.labelBoldSmall)
                                .foregroundStyle(Color.nook.settingsRowIcon)
                        }
                    }
                    .disabled(isSaving)
                }
            }
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
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else { return }
                await MainActor.run {
                    // Wait for the photo picker to finish dismissing, then present
                    // the crop editor item-driven (avoids the blank-cover race).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        cropRequest = CropRequest(image: image, aspect: 1.0, shape: .circle) { cropped in
                            withAnimation(.easeOut(duration: 0.2)) {
                                avatarImage = cropped
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $cropRequest) { req in
            ImageCropView(image: req.image, cropAspect: req.aspect, cropShape: req.shape, onCrop: req.onCrop)
        }
        .task {
            await loadProfile()
        }
        .onChange(of: username) { _, newValue in
            if !usernameCooldownActive {
                validateUsername(newValue)
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 16) {
            Button {
                showPhotoPicker = true
            } label: {
                ZStack {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        AsyncImage(url: avatarURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                Color.nook.secondary
                            }
                        }
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .fill(Color.nook.editProfileAvatarOverlay)
                        .overlay {
                            Image("camera-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.white)
                        }
                }
            }
            .buttonStyle(.plain)

            Text("Tap to change photo")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.settingsRowSubtitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        VStack(spacing: 16) {
            fieldGroup(label: "Display Name", placeholder: "Your name", text: $displayName, field: .name)

            VStack(alignment: .leading, spacing: 4) {
                fieldGroup(
                    label: "Username",
                    placeholder: "@username",
                    text: $username,
                    field: .username,
                    disabled: usernameCooldownActive
                )

                if usernameCooldownActive, let endDate = usernameCooldownEndDate {
                    Text("Can be changed again \(endDate, style: .relative)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.settingsRowSubtitle)
                        .transition(.opacity)
                } else if let usernameError {
                    Text(usernameError)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.settingsDestructiveText)
                        .transition(.opacity)
                }
            }

            bioFieldGroup
        }
    }

    private func fieldGroup(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        disabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(NookFont.captionSemiBold)
                .foregroundStyle(Color.nook.editProfileFieldLabel)

            TextField(
                placeholder,
                text: text,
                prompt: Text(placeholder)
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color.nook.settingsChevron)
            )
            .font(NookFont.bodyMedium)
            .foregroundStyle(disabled ? Color.nook.settingsRowSubtitle : Color.nook.editProfileFieldText)
            .focused($focusedField, equals: field)
            .disabled(disabled)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.nook.editProfileFieldBackground.opacity(disabled ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.nook.editProfileFieldBorder, lineWidth: 1)
            }
        }
    }

    private var bioFieldGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bio")
                    .font(NookFont.captionSemiBold)
                    .foregroundStyle(Color.nook.editProfileFieldLabel)

                Spacer()

                Text("\(bio.count)/150")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.settingsChevron)
            }

            ZStack(alignment: .topLeading) {
                if bio.isEmpty {
                    Text("Tell us about yourself...")
                        .font(NookFont.bodyMedium)
                        .foregroundStyle(Color.nook.settingsChevron)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .onTapGesture { focusedField = .bio }
                }

                TextEditor(text: $bio)
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color.nook.editProfileFieldText)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .bio)
                    .padding(.horizontal, 11)
                    .padding(.top, 6)
                    .frame(minHeight: 100)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 150 {
                            bio = String(newValue.prefix(150))
                        }
                    }
            }
            .background(Color.nook.editProfileFieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.nook.editProfileFieldBorder, lineWidth: 1)
            }
        }
    }

    // MARK: - Data

    private func loadProfile() async {
        guard let user = try? await supabase.auth.session.user else { return }

        let profileService = ProfileService()
        do {
            let profile = try await profileService.getProfile(userId: user.id)
            displayName = profile.fullName ?? ""
            username = profile.username ?? ""
            originalUsername = profile.username ?? ""
            bio = profile.bio ?? ""
            avatarURL = profile.avatarURL
            usernameChangedAt = profile.usernameChangedAt
        } catch {
            // Fall back to auth metadata
            if let name = user.userMetadata["full_name"]?.value as? String {
                displayName = name
            }
        }
    }

    private func validateUsername(_ value: String) {
        usernameCheckTask?.cancel()
        usernameError = nil

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Regex check: alphanumeric + underscore, 3-20 chars
        let regex = /^[a-zA-Z0-9_]{3,20}$/
        if trimmed.wholeMatch(of: regex) == nil {
            withAnimation(.easeOut(duration: 0.2)) {
                usernameError = "3-20 characters, letters, numbers, and underscores only"
            }
            return
        }

        // Debounced availability check
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            let profileService = ProfileService()
            let available = (try? await profileService.checkUsernameAvailable(username: trimmed)) ?? true
            guard !Task.isCancelled else { return }

            if !available {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        usernameError = "Username is already taken"
                    }
                }
            }
        }
    }

    private func saveProfile() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let userId = try await supabase.auth.session.user.id
                let profileService = ProfileService()
                let storageService = StorageService()

                // Upload avatar if changed
                var newAvatarURL: String?
                if let avatarImage {
                    if let jpegData = avatarImage.jpegData(compressionQuality: 0.8) {
                        let url = try await storageService.uploadAvatar(userId: userId, imageData: jpegData)
                        newAvatarURL = url.absoluteString
                    }
                }

                // Only send username if it actually changed and cooldown allows it
                let usernameToSave: String? = (!username.isEmpty && username != originalUsername && !usernameCooldownActive)
                    ? username : nil

                // Update user_profiles table
                try await profileService.updateProfile(
                    userId: userId,
                    fullName: displayName.isEmpty ? nil : displayName,
                    username: usernameToSave,
                    bio: bio.isEmpty ? nil : bio,
                    avatarURL: newAvatarURL
                )

                // Also update auth metadata for display name
                if !displayName.isEmpty {
                    _ = try? await supabase.auth.update(
                        user: UserAttributes(data: ["full_name": .string(displayName)])
                    )
                }

                // Notify callers to refresh before dismissing
                await onSaved?()

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        errorMessage = error.localizedDescription
                    }
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    EditProfileSheet()
}
