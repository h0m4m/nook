import PhotosUI
import Supabase
import SwiftUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var avatarURL: URL?
    @State private var avatarImage: UIImage?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, username, bio
    }

    private var hasChanges: Bool {
        !displayName.isEmpty || !username.isEmpty || !bio.isEmpty || avatarImage != nil
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
                    withAnimation(.easeOut(duration: 0.2)) {
                        avatarImage = image
                    }
                }
            }
        }
        .task {
            await loadProfile()
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
            fieldGroup(label: "Username", placeholder: "@username", text: $username, field: .username)
            bioFieldGroup
        }
    }

    private func fieldGroup(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
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
            .foregroundStyle(Color.nook.editProfileFieldText)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.nook.editProfileFieldBackground)
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

        if let name = user.userMetadata["full_name"]?.value as? String {
            displayName = name
        }

        if let urlString = user.userMetadata["avatar_url"]?.value as? String {
            avatarURL = URL(string: urlString)
        }

        // Load extended profile from user_profiles
        struct ProfileRow: Decodable {
            let username: String?
            let bio: String?
        }

        if let row = try? await supabase
            .from("user_profiles")
            .select("username, bio")
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()
            .value as ProfileRow?
        {
            username = row.username ?? ""
            bio = row.bio ?? ""
        }
    }

    private func saveProfile() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Update auth metadata (display name)
                _ = try await supabase.auth.update(
                    user: UserAttributes(data: ["full_name": .string(displayName)])
                )

                // Update profile in user_profiles table
                let userId = try await supabase.auth.session.user.id

                struct ProfileUpdate: Encodable {
                    let username: String
                    let bio: String
                }

                try await supabase
                    .from("user_profiles")
                    .update(ProfileUpdate(username: username, bio: bio))
                    .eq("id", value: userId.uuidString)
                    .execute()

                // TODO: Upload avatar image to Supabase Storage if changed

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
