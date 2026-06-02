import SwiftUI

struct InviteMemberView: View {
    let clubName: String
    var clubId: UUID?
    var existingMemberIds: Set<UUID> = []

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [ReviewAuthor] = []
    @State private var invitedUsers: Set<UUID> = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private let service = ClubService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader
                searchBar
                userList
            }
            .background(Color.nook.clubDetailBackground)
            .navigationBarHidden(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSearchFocused = true
                }
            }
        }
    }

    private func runSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            let found = (try? await service.searchUsers(query: trimmed)) ?? []
            let filtered = found.filter { !existingMemberIds.contains($0.id) }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                results = filtered
                isSearching = false
            }
        }
    }
}

// MARK: - Header

private extension InviteMemberView {
    var sheetHeader: some View {
        HStack {
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

            Text("Invite People")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Spacer()

            // Balance spacer
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Search Bar

private extension InviteMemberView {
    var searchBar: some View {
        HStack(spacing: 12) {
            Image("magnifying-glass-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.nook.clubDetailMeta)

            TextField(
                "Search by name or username",
                text: $searchText,
                prompt: Text("Search by name or username")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.clubDetailTitle)
            .focused($isSearchFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: searchText) { _, newValue in
                runSearch(newValue)
            }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    results = []
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
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.nook.secondary)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - User List

private extension InviteMemberView {
    var userList: some View {
        ScrollView(showsIndicators: false) {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if results.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(results) { user in
                        userRow(user)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Text(searchText.count < 2 ? "Search for people to invite" : "No users found")
                .font(NookFont.labelSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Text(searchText.count < 2 ? "Find friends by name or username" : "Try a different name or username")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.clubDetailMeta)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    func userRow(_ user: ReviewAuthor) -> some View {
        let isInvited = invitedUsers.contains(user.id)
        let displayName = user.fullName ?? user.username ?? "User"

        return HStack(spacing: 12) {
            ClubAvatarView(url: user.avatarUrl.flatMap { URL(string: $0) }, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)

                if let username = user.username {
                    Text("@\(username)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
            }

            Spacer()

            Button {
                guard !isInvited else { return }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                withAnimation(.easeOut(duration: 0.2)) {
                    invitedUsers.insert(user.id)
                }
                generator.impactOccurred()

                if let clubId {
                    Task {
                        do {
                            try await service.inviteToClub(clubId: clubId, userId: user.id)
                        } catch {
                            await MainActor.run {
                                _ = invitedUsers.remove(user.id)
                            }
                        }
                    }
                }
            } label: {
                Text(isInvited ? "Invited" : "Invite")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(isInvited ? .white : Color.nook.clubDetailTitle)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(
                        Capsule()
                            .fill(isInvited ? Color.nook.clubDetailJoinedButton : .clear)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isInvited ? Color.clear : Color.nook.detailTabBorder,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    InviteMemberView(clubName: "Anime Corner")
}
