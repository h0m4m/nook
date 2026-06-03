import SwiftUI

/// Path-based route so notifications sit in the same NavigationStack as the
/// club/profile destinations they push to (otherwise pushes land underneath).
struct NotificationsRoute: Hashable {}

// MARK: - Notification Models

struct NotificationItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let timestamp: String
}

enum NotificationSection: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case earlier = "Earlier"
}

// MARK: - Notifications View

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [NotificationItem] = []
    @State private var realNotifications: [NotificationModel] = []
    @State private var isLoading = true

    private var displayNotifications: [NotificationItem] {
        if !realNotifications.isEmpty {
            return realNotifications.map { notif in
                NotificationItem(
                    title: notif.message,
                    body: "",
                    timestamp: notif.createdAt.formatted(.relative(presentation: .named))
                )
            }
        }
        return isLoading ? [] : Self.mockNotifications
    }

    private var groupedNotifications: [(NotificationSection, [NotificationItem])] {
        let items = displayNotifications
        guard !items.isEmpty else { return [] }

        // Simple grouping: first 3 = Today, next 4 = This Week, rest = Earlier
        var result: [(NotificationSection, [NotificationItem])] = []
        if items.count > 0 {
            result.append((.today, Array(items.prefix(min(3, items.count)))))
        }
        if items.count > 3 {
            result.append((.thisWeek, Array(items.dropFirst(3).prefix(4))))
        }
        if items.count > 7 {
            result.append((.earlier, Array(items.dropFirst(7))))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 24) {
                    ForEach(0..<4, id: \.self) { _ in
                        SearchShimmerRow()
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 80)
                Spacer()
            } else if displayNotifications.isEmpty {
                emptyState
            } else {
                notificationsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nook.notificationBackground)
        .modifier(NotificationsTopBar(onBack: { dismiss() }))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        isLoading = true
        let service = NotificationService()
        realNotifications = (try? await service.getNotifications()) ?? []

        // Mark all as read
        try? await service.markAllAsRead()
        isLoading = false
    }

    // MARK: - List

    private var notificationsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if realNotifications.isEmpty {
                    notificationsEmptyState
                } else {
                    ForEach(realNotifications) { notif in
                        if notif.referenceType == "club", let clubId = notif.referenceId {
                            NavigationLink(value: ClubItem(navigationId: clubId)) {
                                RealNotificationRow(notification: notif)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: UserProfile.profileFor(name: notif.actorName)) {
                                RealNotificationRow(notification: notif)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
    }

    private var notificationsEmptyState: some View {
        VStack(spacing: 12) {
            Image("bell")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundStyle(Color.nook.notificationSectionHeader)

            Text("No notifications yet")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.notificationTitle)

            Text("Invites, joins and replies will show up here.")
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.notificationSectionHeader)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, 40)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(NookFont.captionSemiBold)
                .foregroundStyle(Color.nook.notificationSectionHeader)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image("bell-simple-slash")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .foregroundStyle(Color.nook.searchEmptyIcon)

            Text("No notifications yet")
                .font(NookFont.label)
                .foregroundStyle(Color.nook.foreground)

            Text("When something happens, you'll see it here")
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.notificationBody)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.nook.secondary)
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(Color.nook.border, lineWidth: 1)
                }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.notificationTitle)

                Text(notification.body)
                    .font(NookFont.bodySmall)
                    .foregroundStyle(Color.nook.notificationBody)
                    .lineLimit(2)

                Text(notification.timestamp)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.notificationTimestamp)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Real Notification Row (from DB)

private struct RealNotificationRow: View {
    let notification: NotificationModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: notification.actorAvatarURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle()
                        .fill(Color.nook.secondary)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.nook.mutedForeground)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.nook.border, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.message)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(notification.isRead ? Color.nook.notificationBody : Color.nook.notificationTitle)

                Text(notification.createdAt, style: .relative)
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.notificationTimestamp)
            }

            Spacer(minLength: 0)

            if !notification.isRead {
                Circle()
                    .fill(Color.nook.primary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Top Bar

private struct NotificationsTopBar: ViewModifier {
    let onBack: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                topBarContent
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                topBarContent
                    .background(Color.nook.notificationBackground)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    private var topBarContent: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image("caret-left-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.notificationTitle)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())

            Text("Notifications")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.notificationTitle)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Mock Data

extension NotificationsView {
    static let mockNotifications: [NotificationItem] = [
        NotificationItem(
            title: "Sarah liked your review",
            body: "\"Attack on Titan is a masterpiece of storytelling...\"",
            timestamp: "12m ago"
        ),
        NotificationItem(
            title: "New review on your tracked media",
            body: "Alex rated Frieren: Beyond Journey's End ★★★★★",
            timestamp: "45m ago"
        ),
        NotificationItem(
            title: "Maya started following you",
            body: "You now have 24 followers",
            timestamp: "2h ago"
        ),
        NotificationItem(
            title: "New post in Shonen Lovers",
            body: "Jordan: \"Just finished the latest chapter of JJK and...\"",
            timestamp: "3h ago"
        ),
        NotificationItem(
            title: "3 people liked your nook",
            body: "\"Best Sci-Fi Anime of 2024\" is gaining traction",
            timestamp: "1d ago"
        ),
        NotificationItem(
            title: "Your nook was featured",
            body: "\"Hidden Gems: Underrated Manga\" is now trending",
            timestamp: "2d ago"
        ),
        NotificationItem(
            title: "Achievement unlocked!",
            body: "You've tracked 50 media items — keep going!",
            timestamp: "3d ago"
        ),
        NotificationItem(
            title: "Taylor replied to your review",
            body: "\"I totally agree, the animation quality in ep 23...\"",
            timestamp: "5d ago"
        ),
        NotificationItem(
            title: "Weekly discussion in Anime Central",
            body: "This week's topic: Best anime openings of all time",
            timestamp: "1w ago"
        ),
        NotificationItem(
            title: "5 new followers this week",
            body: "Riley, Jordan, and 3 others started following you",
            timestamp: "1w ago"
        ),
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
