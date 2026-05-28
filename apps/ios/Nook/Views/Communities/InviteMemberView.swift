import SwiftUI

struct InviteMemberView: View {
    let clubName: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var invitedUsers: Set<UUID> = []
    @FocusState private var isSearchFocused: Bool

    private var filteredUsers: [InviteUser] {
        if searchText.isEmpty { return Self.mockUsers }
        return Self.mockUsers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

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

            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
            if filteredUsers.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredUsers) { user in
                        userRow(user)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Text("No users found")
                .font(NookFont.labelSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Text("Try a different name or username")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.clubDetailMeta)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    func userRow(_ user: InviteUser) -> some View {
        let isInvited = invitedUsers.contains(user.id)

        return HStack(spacing: 12) {
            Circle()
                .fill(Color.nook.secondary)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)

                Text("@\(user.username)")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }

            Spacer()

            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                withAnimation(.easeOut(duration: 0.2)) {
                    if isInvited {
                        invitedUsers.remove(user.id)
                    } else {
                        invitedUsers.insert(user.id)
                    }
                }
                generator.impactOccurred()
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

// MARK: - Invite User Model

struct InviteUser: Identifiable {
    let id = UUID()
    let name: String
    let username: String
}

// MARK: - Mock Data

extension InviteMemberView {
    static let mockUsers: [InviteUser] = [
        InviteUser(name: "Marcus Chen", username: "marcuschen"),
        InviteUser(name: "Yuki Sato", username: "yukisato"),
        InviteUser(name: "Olivia Hart", username: "oliviahart"),
        InviteUser(name: "Devon Ray", username: "devonray"),
        InviteUser(name: "Priya Sharma", username: "priyasharma"),
        InviteUser(name: "Leo Fernandez", username: "leofernandez"),
        InviteUser(name: "Hana Nakamura", username: "hananakamura"),
        InviteUser(name: "Sam Torres", username: "samtorres"),
        InviteUser(name: "Zara Ali", username: "zaraali"),
        InviteUser(name: "Noah Kim", username: "noahkim"),
    ]
}

// MARK: - Preview

#Preview {
    InviteMemberView(clubName: "Anime Corner")
}
