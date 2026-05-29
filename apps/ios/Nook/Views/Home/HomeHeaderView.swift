import SwiftUI

struct HomeHeaderView: View {
    let avatarURL: URL?
    var onAvatarTapped: () -> Void = {}
    var onNotificationsTapped: () -> Void = {}

    var body: some View {
        HStack {
            avatar
            Spacer()
            notificationButton
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Avatar

    private var avatar: some View {
        Button(action: onAvatarTapped) {
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
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.nook.headerAvatarBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }

    // MARK: - Notification Button

    @ViewBuilder
    private var notificationButton: some View {
        if #available(iOS 26, *) {
            glassNotificationButton
        } else {
            classicNotificationButton
        }
    }

    @available(iOS 26, *)
    private var glassNotificationButton: some View {
        Button(action: onNotificationsTapped) {
            Image("bell-fill")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private var classicNotificationButton: some View {
        Button(action: onNotificationsTapped) {
            Circle()
                .fill(Color.nook.headerIconBackground)
                .frame(width: 34, height: 34)
                .overlay {
                    Circle()
                        .stroke(Color.nook.headerIconBorder, lineWidth: 1)
                }
                .overlay {
                    Image("bell-fill")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.nook.headerIconForeground)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        HomeHeaderView(avatarURL: nil)
        Spacer()
    }
    .background(Color.nook.background)
}
