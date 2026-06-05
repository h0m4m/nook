import PhotosUI
import Supabase
import SwiftUI

/// Second onboarding step (before interests): the user confirms how they'll
/// show up on Nook. Display name + avatar are prefilled from their social
/// login; the username is auto-generated from their email but follows the
/// same `^[a-zA-Z0-9_]{3,20}$` rule the rest of the app enforces, and stays
/// fully editable behind a live-validated form.
struct OnboardingProfileView: View {
    var router: AppRouter

    @State private var displayName = ""
    @State private var username = ""

    // Avatar: a freshly-picked/cropped image wins; otherwise we fall back to
    // the social avatar pulled from the auth session.
    @State private var avatarImage: UIImage?
    @State private var socialAvatarURL: URL?
    @State private var cropRequest: CropRequest?
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false

    // Username validation state.
    @State private var usernameError: String?
    @State private var usernameAvailable = false
    @State private var isCheckingUsername = false
    @State private var usernameCheckTask: Task<Void, Never>?

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var appeared = false
    @State private var didPrefill = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, username
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var usernameMatchesRules: Bool {
        // Mirrors the DB CHECK constraint on `user_profiles.username`.
        let regex = #/^[a-zA-Z0-9_]{3,20}$/#
        return trimmedUsername.wholeMatch(of: regex) != nil
    }

    private var isFormValid: Bool {
        !trimmedDisplayName.isEmpty
            && usernameMatchesRules
            && usernameAvailable
            && usernameError == nil
            && !isCheckingUsername
    }

    var body: some View {
        ZStack {
            Color.nook.onboardingBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingProgressBar(currentStep: 1, totalSteps: 2)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)

                // Heading
                Text("Make it yours.")
                    .font(NookFont.outfitDisplay)
                    .foregroundStyle(Color.nook.onboardingHeading)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Text("Set up how you'll show up on Nook. You can always change this later.")
                    .font(NookFont.bodyMedium)
                    .lineSpacing(4)
                    .foregroundStyle(Color.nook.onboardingSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.08), value: appeared)

                ScrollView {
                    VStack(spacing: 24) {
                        avatarSection
                            .padding(.top, 28)

                        VStack(spacing: 18) {
                            displayNameField
                            usernameField
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.16), value: appeared)

                if let errorMessage {
                    Text(errorMessage)
                        .font(NookFont.bodySmall)
                        .foregroundStyle(Color.nook.settingsDestructiveText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.45), value: appeared)
            }
        }
        .animation(.easeOut(duration: 0.5), value: appeared)
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
                    // Let the picker finish dismissing before presenting the crop
                    // editor, item-driven (avoids the blank-cover race).
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
        .onChange(of: username) { _, newValue in
            validateUsername(newValue)
        }
        .task {
            await prefill()
        }
        .onAppear { appeared = true }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Button {
                showPhotoPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatarImageView
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(Color.nook.headerAvatarBorder, lineWidth: 1.5)
                        }

                    // Camera badge
                    ZStack {
                        Circle()
                            .fill(Color.nook.onboardingPrimary)
                            .frame(width: 34, height: 34)
                            .overlay {
                                Circle().stroke(Color.nook.onboardingBackground, lineWidth: 3)
                            }

                        Image("camera-bold")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 15, height: 15)
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text("Tap to change photo")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.onboardingSubtitle)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var avatarImageView: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .scaledToFill()
        } else {
            AsyncImage(url: socialAvatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Circle()
                        .fill(Color.nook.accent)
                        .overlay {
                            Text(avatarInitial)
                                .font(NookFont.outfitHeadingMedium)
                                .foregroundStyle(.white)
                        }
                }
            }
        }
    }

    private var avatarInitial: String {
        let source = trimmedDisplayName.isEmpty ? trimmedUsername : trimmedDisplayName
        return String(source.prefix(1)).uppercased()
    }

    // MARK: - Fields

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Display name")

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $displayName,
                    prompt: Text("Your name")
                        .foregroundStyle(Color.nook.mutedForeground)
                )
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.onboardingHeading)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .username }
                .onChange(of: displayName) { _, newValue in
                    if newValue.count > 50 {
                        displayName = String(newValue.prefix(50))
                    }
                }
            }
            .modifier(OnboardingFieldChrome(isFocused: focusedField == .name))
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Username")

            HStack(spacing: 4) {
                Text("@")
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color.nook.mutedForeground)

                TextField(
                    "",
                    text: $username,
                    prompt: Text("username")
                        .foregroundStyle(Color.nook.mutedForeground)
                )
                .font(NookFont.bodyMedium)
                .foregroundStyle(Color.nook.onboardingHeading)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
                .submitLabel(.done)

                usernameStatusIcon
            }
            .modifier(OnboardingFieldChrome(isFocused: focusedField == .username))

            usernameHelperText
        }
    }

    @ViewBuilder
    private var usernameStatusIcon: some View {
        if isCheckingUsername {
            ProgressView()
                .controlSize(.small)
                .tint(Color.nook.mutedForeground)
        } else if usernameAvailable && usernameError == nil {
            Image("check-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.nook.libraryStatusActive)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var usernameHelperText: some View {
        if let usernameError {
            Text(usernameError)
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.settingsDestructiveText)
                .transition(.opacity)
        } else if usernameAvailable {
            Text("Nice — that one's available.")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.libraryStatusActive)
                .transition(.opacity)
        } else {
            Text("This is how friends will find you.")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.onboardingSubtitle)
                .transition(.opacity)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(NookFont.captionSemiBold)
            .foregroundStyle(Color.nook.onboardingSubtitle)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.custom("PlusJakartaSans-Bold", size: 18))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(isFormValid ? Color.nook.onboardingPrimary : Color.nook.onboardingPrimary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 18.89, style: .continuous))
            .shadow(color: Color.nook.onboardingPrimary.opacity(0.2), radius: 12.5, x: 0, y: 10)
            .shadow(color: Color.nook.onboardingPrimary.opacity(0.2), radius: 5, x: 0, y: 4)
        }
        .buttonStyle(OnboardingScaleButtonStyle())
        .disabled(!isFormValid || isSaving)
        .animation(.easeOut(duration: 0.2), value: isFormValid)
    }

    // MARK: - Prefill

    private func prefill() async {
        guard !didPrefill else { return }
        didPrefill = true

        guard let user = try? await supabase.auth.session.user else { return }

        if displayName.isEmpty, let name = user.userMetadata["full_name"]?.value as? String {
            displayName = name
        }

        if let urlString = user.userMetadata["avatar_url"]?.value as? String {
            socialAvatarURL = URL(string: AppRouter.highResAvatarURL(urlString))
        }

        if username.isEmpty, let email = user.email {
            await suggestUsername(from: email)
        }
    }

    /// Build a valid username from the email local-part, then nudge past any
    /// already-taken suggestion so the default the user sees is usable.
    private func suggestUsername(from email: String) async {
        let base = AppRouter.suggestedUsername(fromEmail: email)
        username = base

        let service = ProfileService()
        var candidate = base
        for _ in 0..<5 {
            let available = (try? await service.checkUsernameAvailable(username: candidate)) ?? true
            if available { break }
            let suffix = String(Int.random(in: 10...999))
            let room = max(3, 20 - suffix.count)
            candidate = String(base.prefix(room)) + suffix
        }
        if candidate != username {
            username = candidate
        }
    }

    // MARK: - Username validation

    private func validateUsername(_ value: String) {
        usernameCheckTask?.cancel()

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            withAnimation(.easeOut(duration: 0.2)) {
                usernameError = nil
                usernameAvailable = false
                isCheckingUsername = false
            }
            return
        }

        let regex = #/^[a-zA-Z0-9_]{3,20}$/#
        if trimmed.wholeMatch(of: regex) == nil {
            withAnimation(.easeOut(duration: 0.2)) {
                usernameError = "3–20 characters · letters, numbers & underscores"
                usernameAvailable = false
                isCheckingUsername = false
            }
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            usernameError = nil
            usernameAvailable = false
            isCheckingUsername = true
        }

        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }

            let service = ProfileService()
            let available = (try? await service.checkUsernameAvailable(username: trimmed)) ?? true
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    isCheckingUsername = false
                    usernameAvailable = available
                    usernameError = available ? nil : "That username is taken."
                }
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        guard isFormValid else { return }

        isSaving = true
        errorMessage = nil

        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()

        Task {
            do {
                var imageData: Data?
                if let avatarImage {
                    imageData = avatarImage.jpegData(compressionQuality: 0.8)
                }

                try await router.saveProfileSetup(
                    displayName: trimmedDisplayName,
                    username: trimmedUsername,
                    avatarImageData: imageData
                )
                haptic.notificationOccurred(.success)
            } catch {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        errorMessage = error.localizedDescription
                    }
                    isSaving = false
                }
                haptic.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Shared onboarding progress bar

/// Step indicator shared across the onboarding form steps (profile + interests).
struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 100)
                    .fill(
                        index < currentStep
                            ? Color.nook.onboardingPrimary
                            : Color.nook.onboardingPrimary.opacity(0.2)
                    )
                    .frame(width: 48, height: 6)
            }
            Spacer()
        }
    }
}

// MARK: - Field chrome

private struct OnboardingFieldChrome: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.nook.card)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.nook.onboardingPrimary : Color.nook.border,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Button Style

private struct OnboardingScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingProfileView(router: AppRouter())
}
