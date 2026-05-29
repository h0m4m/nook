import SwiftUI

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
    private let notifications = Self.mockNotifications

    private var groupedNotifications: [(NotificationSection, [NotificationItem])] {
        NotificationSection.allCases.compactMap { section in
            let items = notifications.filter { item in
                switch section {
                case .today:
                    return item.timestamp.hasSuffix("m ago") || item.timestamp.hasSuffix("h ago")
                case .thisWeek:
                    return item.timestamp.hasSuffix("d ago")
                case .earlier:
                    return item.timestamp.hasSuffix("w ago")
                }
            }
            return items.isEmpty ? nil : (section, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if notifications.isEmpty {
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
    }

    // MARK: - List

    private var notificationsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(groupedNotifications, id: \.0) { section, items in
                    sectionHeader(section.rawValue)

                    ForEach(items) { notification in
                        NotificationRow(notification: notification)

                        if notification.id != items.last?.id {
                            Divider()
                                .foregroundStyle(Color.nook.notificationDivider)
                                .padding(.leading, 68)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .modifier(SoftScrollEdge())
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
