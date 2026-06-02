import Supabase
import SwiftUI

struct EditInterestsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedInterests: Set<String> = []
    @State private var isSaving = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var trackedMediaTypes: Set<String> = []
    @State private var interestToRemove: MediaInterest?
    @State private var showRemoveAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Color.nook.settingsRowIcon)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Select the media you want to track and explore.")
                            .font(NookFont.bodyMedium)
                            .foregroundStyle(Color.nook.settingsRowSubtitle)
                            .lineSpacing(4)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(MediaInterest.allCases) { interest in
                                InterestToggleCard(
                                    interest: interest,
                                    isSelected: selectedInterests.contains(interest.rawValue)
                                ) {
                                    toggleInterest(interest)
                                }
                            }
                        }

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
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.nook.settingsBackground)
        .task {
            await loadInterests()
        }
        .alert("Remove \(interestToRemove?.label ?? "")?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {
                interestToRemove = nil
            }
            Button("Remove", role: .destructive) {
                confirmRemoveInterest()
            }
        } message: {
            Text("You have tracked \(interestToRemove?.label.lowercased() ?? "") in your library. Removing this interest will hide it from search and recommendations, but your tracked items won't be deleted.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        ZStack {
            Text("Interests")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.settingsRowLabel)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.nook.settingsRowLabel)
                        .frame(width: 36, height: 36)
                        .background(Color.nook.segmentBackground, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 60, height: 36)
                    } else {
                        Text("Save")
                            .font(NookFont.labelBoldSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 36)
                    }
                }
                .background(
                    Capsule()
                        .fill(
                            selectedInterests.isEmpty
                                ? Color.nook.onboardingPrimary.opacity(0.4)
                                : Color.nook.onboardingPrimary
                        )
                )
                .clipShape(Capsule())
                .buttonStyle(.plain)
                .disabled(selectedInterests.isEmpty || isSaving)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Actions

    private func toggleInterest(_ interest: MediaInterest) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        if selectedInterests.contains(interest.rawValue) {
            // Check if user has tracked media for this interest
            let apiType = interest.apiMediaType
            if trackedMediaTypes.contains(apiType) {
                interestToRemove = interest
                showRemoveAlert = true
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedInterests.remove(interest.rawValue)
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedInterests.insert(interest.rawValue)
                generator.impactOccurred()
            }
        }
    }

    private func confirmRemoveInterest() {
        guard let interest = interestToRemove else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedInterests.remove(interest.rawValue)
        }
        interestToRemove = nil
    }

    private func loadInterests() async {
        guard let user = try? await supabase.auth.session.user else {
            isLoading = false
            return
        }

        struct ProfileRow: Decodable {
            let interests: [String]?
        }

        do {
            let row: ProfileRow = try await supabase
                .from("user_profiles")
                .select("interests")
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value

            if let interests = row.interests {
                selectedInterests = Set(interests)
            }
        } catch {
            // Default to all if can't load
            selectedInterests = Set(MediaInterest.allCases.map(\.rawValue))
        }

        // Load which media types the user has tracked
        struct TrackedWithMedia: Decodable {
            let mediaItem: TrackedMediaType?

            enum CodingKeys: String, CodingKey {
                case mediaItem = "media_item"
            }
        }

        struct TrackedMediaType: Decodable {
            let mediaType: String

            enum CodingKeys: String, CodingKey {
                case mediaType = "media_type"
            }
        }

        if let rows: [TrackedWithMedia] = try? await supabase
            .from("tracked_media")
            .select("media_item:media_items(media_type)")
            .eq("user_id", value: user.id.uuidString)
            .execute()
            .value
        {
            trackedMediaTypes = Set(rows.compactMap { $0.mediaItem?.mediaType })
        }

        isLoading = false
    }

    private func save() {
        guard !selectedInterests.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let userId = try await supabase.auth.session.user.id

                struct InterestsUpdate: Encodable {
                    let interests: [String]
                }

                let sorted = Array(selectedInterests).sorted()

                try await supabase
                    .from("user_profiles")
                    .update(InterestsUpdate(interests: sorted))
                    .eq("id", value: userId.uuidString)
                    .execute()

                // Update local cache so SearchView picks it up instantly
                let categories = SearchMediaCategory.allCases.filter {
                    sorted.contains($0.rawValue)
                }
                if !categories.isEmpty {
                    InterestsCache.save(categories)
                }

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

// MARK: - Interest Toggle Card

private struct InterestToggleCard: View {
    let interest: MediaInterest
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 17.78, style: .continuous)
                            .fill(interest.iconBackgroundColor)
                            .frame(width: 56, height: 56)

                        Image(interest.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .foregroundStyle(interest.iconColor)
                    }

                    Text(interest.label)
                        .font(NookFont.outfitLabel)
                        .foregroundStyle(Color.nook.onboardingHeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.nook.onboardingPrimary)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 18)
                    .padding(.trailing, 18)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 144)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadii.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.nook.onboardingPrimary
                            : Color(hex: 0xE8E3E1, alpha: 0.5),
                        lineWidth: 2
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(InterestCardButtonStyle())
    }
}

private struct InterestCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    EditInterestsSheet()
}
