import Foundation
import Supabase
import SwiftUI

// MARK: - Types

/// Reasons a user can pick when reporting content. Raw values are persisted to
/// `reports.reason`, so keep them stable.
enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam
    case harassment
    case hate
    case violence
    case sexual
    case selfHarm = "self_harm"
    case misinformation
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: "Spam or scam"
        case .harassment: "Harassment or bullying"
        case .hate: "Hate speech or symbols"
        case .violence: "Violence or threats"
        case .sexual: "Nudity or sexual content"
        case .selfHarm: "Self-harm or suicide"
        case .misinformation: "False information"
        case .other: "Something else"
        }
    }
}

/// A user you've blocked, with enough profile info to render a management row.
struct BlockedAccount: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let username: String?
    let avatarURL: URL?
    let blockedAt: Date?
}

// MARK: - Service

/// Single source of truth for moderation actions (report / block / unblock).
///
/// Block *enforcement* lives in the database (RESTRICTIVE RLS policies backed by
/// `private.is_blocked`), so calling `block` here is enough to hide a user's
/// content everywhere — there's no per-screen filtering to keep in sync.
/// Reports are written to the shared `reports` table; there is no in-app
/// consumer yet (moderation tooling is future work).
final class ModerationService: Sendable {

    // MARK: Reporting

    func report(
        targetType: String,
        targetId: UUID,
        reportedUserId: UUID?,
        reason: ReportReason,
        details: String? = nil
    ) async throws {
        let reporterId = try await supabase.auth.session.user.id

        struct ReportUpsert: Encodable {
            let reporter_id: String
            let target_type: String
            let target_id: String
            let reported_user_id: String?
            let reason: String
            let details: String?
        }

        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)

        try await supabase
            .from("reports")
            .upsert(
                ReportUpsert(
                    reporter_id: reporterId.uuidString,
                    target_type: targetType,
                    target_id: targetId.uuidString,
                    reported_user_id: reportedUserId?.uuidString,
                    reason: reason.rawValue,
                    details: (trimmed?.isEmpty ?? true) ? nil : trimmed
                ),
                onConflict: "reporter_id,target_type,target_id"
            )
            .execute()
    }

    // MARK: Blocking

    /// Block a user. Idempotent — re-blocking is a no-op.
    func block(userId blockedId: UUID) async throws {
        let blockerId = try await supabase.auth.session.user.id

        struct BlockInsert: Encodable {
            let blocker_id: String
            let blocked_id: String
        }

        try await supabase
            .from("user_blocks")
            .upsert(
                BlockInsert(blocker_id: blockerId.uuidString, blocked_id: blockedId.uuidString),
                onConflict: "blocker_id,blocked_id"
            )
            .execute()
    }

    func unblock(userId blockedId: UUID) async throws {
        let blockerId = try await supabase.auth.session.user.id

        try await supabase
            .from("user_blocks")
            .delete()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
    }

    func blockedUserIds() async throws -> Set<UUID> {
        let blockerId = try await supabase.auth.session.user.id

        struct Row: Decodable { let blocked_id: UUID }

        let rows: [Row] = try await supabase
            .from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: blockerId.uuidString)
            .execute()
            .value

        return Set(rows.map(\.blocked_id))
    }

    /// Blocked users with profile info for the management screen.
    func blockedAccounts() async throws -> [BlockedAccount] {
        let blockerId = try await supabase.auth.session.user.id

        struct BlockRow: Decodable {
            let blocked_id: UUID
            let created_at: Date?
        }

        let blocks: [BlockRow] = try await supabase
            .from("user_blocks")
            .select("blocked_id, created_at")
            .eq("blocker_id", value: blockerId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        let ids = blocks.map(\.blocked_id.uuidString)
        guard !ids.isEmpty else { return [] }

        struct ProfileRow: Decodable {
            let id: UUID
            let full_name: String?
            let username: String?
            let avatar_url: String?
        }

        let profiles: [ProfileRow] = try await supabase
            .from("user_profiles")
            .select("id, full_name, username, avatar_url")
            .in("id", values: ids)
            .execute()
            .value

        let byId = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        return blocks.map { block in
            let profile = byId[block.blocked_id]
            return BlockedAccount(
                id: block.blocked_id,
                name: profile?.full_name ?? profile?.username ?? "Unknown user",
                username: profile?.username,
                avatarURL: profile?.avatar_url.flatMap { URL(string: $0) },
                blockedAt: block.created_at
            )
        }
    }
}

// MARK: - Block Store

/// App-wide, observable cache of who the current user has blocked.
///
/// The database (RLS) is the source of truth and filters blocked content on every
/// fetch. This store exists for *immediacy*: blocking optimistically updates the
/// set so already-loaded lists drop the user's content instantly, without waiting
/// for a refetch. Content views filter against `blockedUserIds` / `isBlocked(_:)`;
/// because it's `@Observable`, any such view re-renders the moment a block changes.
///
/// Route every block/unblock through here (not `ModerationService` directly) so the
/// in-memory set and the database stay in lockstep.
@MainActor
@Observable
final class BlockStore {
    static let shared = BlockStore()

    private(set) var blockedUserIds: Set<UUID> = []

    private let moderation = ModerationService()

    nonisolated private init() {}

    /// Load the blocked set from the server. Call once at app launch.
    func refresh() async {
        blockedUserIds = (try? await moderation.blockedUserIds()) ?? []
    }

    func isBlocked(_ userId: UUID?) -> Bool {
        guard let userId else { return false }
        return blockedUserIds.contains(userId)
    }

    /// Optimistically hide the user everywhere, then persist the block.
    func block(userId: UUID) async {
        blockedUserIds.insert(userId)
        try? await moderation.block(userId: userId)
    }

    func unblock(userId: UUID) async {
        blockedUserIds.remove(userId)
        try? await moderation.unblock(userId: userId)
    }
}

// MARK: - Report Sheet

/// Reusable reason picker presented when reporting any content. Hands the chosen
/// reason (and optional free-text detail) back to the caller, which performs the
/// actual `ModerationService.report` call.
struct ReportSheet: View {
    /// Human-readable noun for what's being reported, e.g. "review", "post".
    let subject: String
    let onSubmit: (ReportReason, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: ReportReason?
    @State private var details: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why are you reporting this \(subject)?")
                        .font(NookFont.labelBold)
                        .foregroundStyle(Color.nook.settingsRowLabel)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(ReportReason.allCases.enumerated()), id: \.element.id) { index, reason in
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { selected = reason }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(reason.label)
                                        .font(NookFont.label)
                                        .foregroundStyle(Color.nook.settingsRowLabel)
                                    Spacer()
                                    if selected == reason {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.nook.settingsToggleOn)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < ReportReason.allCases.count - 1 {
                                Rectangle()
                                    .fill(Color.nook.settingsDivider)
                                    .frame(height: 1)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.nook.settingsSectionBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NookRadii.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: NookRadii.md)
                            .stroke(Color.nook.settingsSectionBorder, lineWidth: 1)
                    )

                    if selected == .other {
                        TextField("Add details (optional)", text: $details, axis: .vertical)
                            .font(NookFont.label)
                            .lineLimit(3, reservesSpace: true)
                            .padding(12)
                            .background(Color.nook.settingsSectionBackground)
                            .clipShape(RoundedRectangle(cornerRadius: NookRadii.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: NookRadii.md)
                                    .stroke(Color.nook.settingsSectionBorder, lineWidth: 1)
                            )
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.nook.settingsBackground)
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.nook.settingsRowSubtitle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        guard let selected else { return }
                        onSubmit(selected, details)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selected == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.nook.settingsBackground)
    }
}

// MARK: - Blocked Accounts Screen

struct BlockedAccountsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [BlockedAccount] = []
    @State private var isLoading = true
    @State private var unblocking: Set<UUID> = []

    private let moderation = ModerationService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if accounts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(accounts) { account in
                                row(for: account)
                                if account.id != accounts.last?.id {
                                    Rectangle()
                                        .fill(Color.nook.settingsDivider)
                                        .frame(height: 1)
                                        .padding(.leading, 64)
                                }
                            }
                        }
                        .background(Color.nook.settingsSectionBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NookRadii.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: NookRadii.md)
                                .stroke(Color.nook.settingsSectionBorder, lineWidth: 1)
                        )
                        .padding(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.nook.settingsBackground)
            .navigationTitle("Blocked Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.nook.settingsRowSubtitle)
            Text("No blocked accounts")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.settingsRowLabel)
            Text("People you block won't be able to appear in your feeds, and you won't see their content.")
                .font(NookFont.caption)
                .foregroundStyle(Color.nook.settingsRowSubtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func row(for account: BlockedAccount) -> some View {
        HStack(spacing: 12) {
            avatar(for: account)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(NookFont.label)
                    .foregroundStyle(Color.nook.settingsRowLabel)
                if let username = account.username {
                    Text("@\(username)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.settingsRowSubtitle)
                }
            }

            Spacer()

            Button {
                Task { await unblock(account) }
            } label: {
                Text(unblocking.contains(account.id) ? "…" : "Unblock")
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.settingsRowLabel)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.nook.settingsRowIconBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(unblocking.contains(account.id))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func avatar(for account: BlockedAccount) -> some View {
        Group {
            if let url = account.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: initials(for: account.name)
                    }
                }
            } else {
                initials(for: account.name)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func initials(for name: String) -> some View {
        Circle()
            .fill(Color.nook.settingsRowIconBackground)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.settingsRowSubtitle)
            )
    }

    private func load() async {
        isLoading = true
        accounts = (try? await moderation.blockedAccounts()) ?? []
        isLoading = false
    }

    private func unblock(_ account: BlockedAccount) async {
        unblocking.insert(account.id)
        defer { unblocking.remove(account.id) }
        // Route through the store so the app-wide blocked set updates too (their
        // content reappears in live lists immediately).
        await BlockStore.shared.unblock(userId: account.id)
        withAnimation(.easeOut(duration: 0.2)) {
            accounts.removeAll { $0.id == account.id }
        }
    }
}
