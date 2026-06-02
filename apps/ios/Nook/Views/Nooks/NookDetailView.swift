import SwiftUI

// MARK: - Comment Model

struct NookComment: Identifiable, Hashable {
    let id = UUID()
    let dbId: UUID?
    let userId: UUID?
    let authorName: String
    let authorAvatarURL: URL?
    let createdAt: Date?
    let body: String
    var likes: Int
    var isLiked: Bool
    var isCollapsed: Bool
    var replies: [NookComment]

    init(
        dbId: UUID? = nil,
        userId: UUID? = nil,
        authorName: String,
        authorAvatarURL: URL? = nil,
        createdAt: Date? = nil,
        body: String,
        likes: Int = 0,
        isLiked: Bool = false,
        isCollapsed: Bool = true,
        replies: [NookComment] = []
    ) {
        self.dbId = dbId
        self.userId = userId
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.createdAt = createdAt
        self.body = body
        self.likes = likes
        self.isLiked = isLiked
        self.isCollapsed = isCollapsed
        self.replies = replies
    }
}

// MARK: - Detail View

struct NookDetailView: View {
    @State private var nook: NookItem
    @Environment(\.dismiss) private var dismiss
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var commentText = ""
    @State private var comments: [NookComment] = []
    @State private var replyingToName: String?
    @State private var replyingToId: UUID?
    @State private var expandedNoteID: UUID?
    @State private var sortOrder: CommentSort = .top
    @State private var currentUserId: UUID?
    @State private var showDeleteConfirm = false
    @FocusState private var isCommentFocused: Bool

    init(nook: NookItem) {
        self._nook = State(initialValue: nook)
        self._likeCount = State(initialValue: nook.likes)
    }

    private var isOwner: Bool {
        guard let owner = nook.ownerUserId, let me = currentUserId else { return false }
        return owner == me
    }

    private var totalCommentCount: Int {
        comments.reduce(0) { $0 + 1 + replyCount($1) }
    }

    private func replyCount(_ comment: NookComment) -> Int {
        comment.replies.reduce(0) { $0 + 1 + replyCount($1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    coverSection
                    headerInfo
                    contentSection
                }
            }
            .scrollDismissesKeyboard(.interactively)

            replyBar
        }
        .background(Color.nook.detailBackground.ignoresSafeArea())
        .modifier(NookDetailHeaderBar { headerBar })
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .confirmationDialog(
            "Delete this nook?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteNook() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the nook and all its items. This can't be undone.")
        }
        .task {
            await loadDetail()
        }
    }

    // MARK: - Data

    private func loadDetail() async {
        currentUserId = try? await supabase.auth.session.user.id

        guard let dbId = nook.dbId else { return }
        let nookService = NookService()

        if let detail = try? await nookService.getNook(nookId: dbId) {
            nook = NookItem(from: detail)
            likeCount = detail.nook.likesCount
        }

        isLiked = (try? await nookService.isNookLiked(nookId: dbId)) ?? false
        await reloadComments()
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 30 { return "\(days)d" }
        let months = days / 30
        if months < 12 { return "\(months)mo" }
        return "\(months / 12)y"
    }

    // MARK: - Cover + Header Info

    // Rounded, inset cover image — rectangular (393:192), matching the club banner shape.
    private var coverSection: some View {
        Color.clear
            .aspectRatio(393.0 / 192.0, contentMode: .fit)
            .overlay { coverImage }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let url = nook.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    nook.placeholderColor ?? Color.nook.searchShimmerBase
                }
            }
        } else if let color = nook.placeholderColor {
            color
        } else if !nook.imageName.isEmpty {
            Image(nook.imageName)
                .resizable()
                .scaledToFill()
        } else {
            Color.nook.searchShimmerBase
        }
    }

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(nook.title)
                .font(.custom("Outfit-Bold", size: 26))
                .lineSpacing(2)
                .foregroundStyle(Color.nook.detailTitle)

            // Author — tappable to open the curator's profile
            if let profile = ownerProfile {
                NavigationLink(value: profile) { authorRow }
                    .buttonStyle(.plain)
            } else {
                authorRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            authorAvatar

            VStack(alignment: .leading, spacing: 0) {
                Text(nook.curatorName)
                    .font(NookFont.captionSemiBold)
                    .foregroundStyle(Color(hex: 0x1C1917))

                if let created = nook.createdAt {
                    Text("Published \(created.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.custom("PlusJakartaSans-Regular", size: 10))
                        .foregroundStyle(Color(hex: 0x78716C))
                }
            }
        }
    }

    /// Profile of the nook's curator, for navigation.
    private var ownerProfile: UserProfile? {
        guard let userId = nook.ownerUserId else { return nil }
        return profile(userId: userId, name: nook.curatorName, avatar: nook.curatorAvatarURL)
    }

    private func profile(userId: UUID, name: String, avatar: URL?) -> UserProfile {
        UserProfile(
            id: userId.uuidString,
            displayName: name,
            username: "",
            bio: "",
            avatarURL: avatar,
            followersCount: 0,
            followingCount: 0,
            trackedMedia: 0,
            reviewsWritten: 0,
            curatedNooks: 0,
            clubs: 0,
            tasteIdentity: [],
            recentActivity: [],
            isCurrentUser: userId == currentUserId
        )
    }

    private var authorAvatar: some View {
        Group {
            if let url = nook.curatorAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarFallback
                    }
                }
            } else {
                avatarFallback
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(hex: 0xFDFCF9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color.nook.secondary)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nook.mutedForeground)
            )
    }

    // MARK: - Header Bar (lives in the top safe area)

    private var headerBar: some View {
        HStack(spacing: 8) {
            heroButton(icon: "caret-left-bold", action: { dismiss() })

            Spacer()

            heroButton(icon: "heart", action: toggleLike)

            trailingButton
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isOwner {
            heroMenu {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete nook", systemImage: "trash")
                }
            } label: {
                heroButtonLabel(icon: "dots-three-bold", isHeartFilled: false)
            }
        } else {
            ShareLink(item: shareText) {
                heroButtonLabel(icon: "export", isHeartFilled: false)
            }
            .buttonStyle(.plain)
        }
    }

    private var shareText: String {
        "Check out \"\(nook.title)\" on Nook"
    }

    private func toggleLike() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        let wasLiked = isLiked
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likeCount += wasLiked ? -1 : 1
        }
        generator.impactOccurred()

        guard let dbId = nook.dbId else { return }
        Task {
            let service = NookService()
            if wasLiked {
                try? await service.unlikeNook(nookId: dbId)
            } else {
                try? await service.likeNook(nookId: dbId)
            }
        }
    }

    @ViewBuilder
    private func heroButtonLabel(icon: String, isHeartFilled: Bool) -> some View {
        let resolvedIcon = isHeartFilled ? "heart-fill" : icon

        if #available(iOS 26, *) {
            Image(resolvedIcon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(isHeartFilled ? Color.nook.clubDetailLikeActive : .primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Image(resolvedIcon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(isHeartFilled ? Color.nook.clubDetailLikeActive : .primary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    private func heroButton(icon: String, action: @escaping () -> Void) -> some View {
        let isHeartFilled = icon == "heart" && isLiked

        Button(action: action) {
            heroButtonLabel(icon: icon, isHeartFilled: isHeartFilled)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func heroMenu<MenuContent: View, Label: View>(
        @ViewBuilder content: () -> MenuContent,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Menu {
            content()
        } label: {
            label()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Description
            if !nook.description.isEmpty {
                Text(nook.description)
                    .font(NookFont.bodyMedium)
                    .foregroundStyle(Color.nook.detailMeta)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
            }

            // Stats
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image(isLiked ? "heart-fill" : "heart")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(isLiked ? Color.nook.clubDetailLikeActive : Color.nook.detailMeta)
                    Text("\(likeCount)")
                        .font(NookFont.captionSemiBold)
                        .foregroundStyle(Color.nook.detailMeta)
                }

                HStack(spacing: 5) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text("\(totalCommentCount)")
                        .font(NookFont.captionSemiBold)
                }
                .foregroundStyle(Color.nook.detailMeta)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Divider
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Collection header
            HStack {
                Text("The Collection")
                    .font(NookFont.outfitHeadingSmall)
                    .foregroundStyle(Color(hex: 0x1C1917))

                Spacer()

                Text("\(nook.mediaItems.count) Items")
                    .font(NookFont.captionSemiBold)
                    .foregroundStyle(Color(hex: 0x78716C))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4.5)
                    .background(Color(hex: 0xF5F3EF), in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // Media grid
            itemsGrid
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            // Divider
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Comments header
            HStack {
                Text("Comments")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.detailTitle)

                Spacer()

                if !comments.isEmpty {
                    Menu {
                        ForEach(CommentSort.allCases, id: \.self) { sort in
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    sortOrder = sort
                                    sortComments()
                                }
                            } label: {
                                HStack {
                                    Text(sort.label)
                                    if sortOrder == sort {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image("sort-ascending-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)

                            Text(sortOrder.label)
                                .font(NookFont.captionBold)
                        }
                        .foregroundStyle(Color.nook.detailMeta)
                    }
                } else {
                    Text("\(totalCommentCount)")
                        .font(NookFont.labelMediumSmall)
                        .foregroundStyle(Color.nook.detailMeta)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // Comments
            if comments.isEmpty {
                emptyCommentsState
            } else {
                commentsSection
            }
        }
        .background(Color.nook.detailBackground)
    }

    private var emptyCommentsState: some View {
        VStack(spacing: 8) {
            Image("chat-circle")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .foregroundStyle(Color.nook.detailMeta.opacity(0.5))

            Text("No comments yet")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.detailMeta)

            Text("Be the first to share what you think")
                .font(NookFont.bodySmall)
                .foregroundStyle(Color.nook.detailMeta.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.bottom, 40)
    }

    // MARK: - Items Grid

    private var itemsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(nook.mediaItems) { item in
                nookMediaCard(item)
            }
        }
    }

    private func nookMediaCard(_ item: NookMediaItem) -> some View {
        let isFlipped = expandedNoteID == item.id
        let hasNote = item.note != nil

        return VStack(alignment: .leading, spacing: 6) {
            // Flippable card
            ZStack {
                // Front — poster
                cardFront(item: item, hasNote: hasNote)
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )

                // Back — note
                if let note = item.note {
                    cardBack(item: item, note: note)
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(isFlipped ? 0 : -180),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .onTapGesture {
                guard hasNote else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                    expandedNoteID = isFlipped ? nil : item.id
                }
            }

            // Title
            Text(item.title)
                .font(NookFont.captionBold)
                .foregroundStyle(Color.nook.detailTitle)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
    }

    private func cardFront(item: NookMediaItem, hasNote: Bool) -> some View {
        GeometryReader { geo in
            Group {
                if let url = item.imageURL {
                    MediaPosterImage(
                        url: url,
                        width: geo.size.width,
                        height: geo.size.height,
                        cornerRadius: 20
                    )
                } else if let color = item.placeholderColor {
                    color
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if !item.imageName.isEmpty {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    Color.nook.searchShimmerBase
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if hasNote {
                    Image("notes")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(10)
                }
            }
        }
    }

    private func cardBack(item: NookMediaItem, note: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Curator's note header
            HStack(spacing: 6) {
                Image("pencil-line")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color(hex: 0x43313D))

                Text("Note")
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color(hex: 0x43313D))
            }
            .padding(.bottom, 10)

            // Note text
            Text(note)
                .font(NookFont.caption)
                .foregroundStyle(Color(hex: 0x44403C))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Tap hint
            Text("Tap to flip back")
                .font(.custom("PlusJakartaSans-Medium", size: 9))
                .foregroundStyle(Color(hex: 0x78716C).opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0xF5F1EC))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: 0xE6E2E0), lineWidth: 1)
        )
    }

    // MARK: - Comments

    private static let defaultVisibleReplies = 2
    private static let maxDepth = 4

    private var commentsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(comments) { comment in
                renderCommentTree(comment, depth: 0)
            }
        }
        .padding(.bottom, 40)
    }

    private func engagement(_ c: NookComment) -> Int {
        c.likes + c.replies.count
    }

    private func renderCommentTree(_ comment: NookComment, depth: Int) -> AnyView {
        let topReplies = comment.replies
            .sorted { engagement($0) > engagement($1) }
        let visibleReplies = comment.isCollapsed
            ? Array(topReplies.prefix(Self.defaultVisibleReplies))
            : comment.replies
        let visibleIds = Set(visibleReplies.map(\.id))
        let hiddenReplies = comment.replies.filter { !visibleIds.contains($0.id) }
        let totalHidden = hiddenReplies.reduce(0) { $0 + 1 + totalReplyCount($1) }

        return AnyView(
            VStack(spacing: 0) {
                commentRow(comment, depth: depth)

                ForEach(visibleReplies) { reply in
                    renderCommentTree(reply, depth: depth + 1)
                }

                if comment.isCollapsed && totalHidden > 0 {
                    collapseToggle(
                        depth: depth,
                        label: "View \(totalHidden) more \(totalHidden == 1 ? "reply" : "replies")",
                        accent: true,
                        commentDbId: comment.dbId
                    )
                }

                if !comment.isCollapsed && comment.replies.count > Self.defaultVisibleReplies {
                    collapseToggle(
                        depth: depth,
                        label: "Hide replies",
                        accent: false,
                        commentDbId: comment.dbId
                    )
                }
            }
        )
    }

    private func collapseToggle(depth: Int, label: String, accent: Bool, commentDbId: UUID?) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                toggleCollapsed(commentDbId: commentDbId)
            }
        } label: {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.nook.detailTabBorder)
                    .frame(width: 2, height: 12)

                Text(label)
                    .font(NookFont.captionBold)
                    .foregroundStyle(accent ? Color.nook.detailTabActive : Color.nook.detailMeta)
            }
            .padding(.leading, 24 + CGFloat(min(depth + 1, Self.maxDepth)) * 24)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func totalReplyCount(_ comment: NookComment) -> Int {
        comment.replies.reduce(0) { $0 + 1 + totalReplyCount($1) }
    }

    @ViewBuilder
    private func commentAvatar(_ comment: NookComment, depth: Int) -> some View {
        let size: CGFloat = depth == 0 ? 36 : 28
        let avatar = Group {
            if let url = comment.authorAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: commentAvatarFallback(depth: depth)
                    }
                }
            } else {
                commentAvatarFallback(depth: depth)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())

        if let profile = userProfile(for: comment) {
            NavigationLink(value: profile) { avatar }
                .buttonStyle(.plain)
        } else {
            avatar
        }
    }

    private func commentAvatarFallback(depth: Int) -> some View {
        Circle()
            .fill(Color.nook.secondary)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: depth == 0 ? 14 : 11))
                    .foregroundStyle(Color.nook.mutedForeground)
            )
    }

    @ViewBuilder
    private func commentAuthorLink(_ comment: NookComment) -> some View {
        if let profile = userProfile(for: comment) {
            NavigationLink(value: profile) {
                Text(comment.authorName)
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.detailTitle)
            }
            .buttonStyle(.plain)
        } else {
            Text(comment.authorName)
                .font(NookFont.captionBold)
                .foregroundStyle(Color.nook.detailTitle)
        }
    }

    private func userProfile(for comment: NookComment) -> UserProfile? {
        guard let userId = comment.userId else { return nil }
        return profile(userId: userId, name: comment.authorName, avatar: comment.authorAvatarURL)
    }

    private func commentRow(_ comment: NookComment, depth: Int) -> some View {
        let indent = CGFloat(min(depth, Self.maxDepth)) * 24
        return HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.nook.detailTabBorder)
                    .frame(width: 2)
            }

            commentAvatar(comment, depth: depth)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    commentAuthorLink(comment)

                    if let date = comment.createdAt {
                        Text(relativeTime(from: date))
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.detailMeta)
                    }
                }

                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailTitle)
                    .lineSpacing(4)

                HStack(spacing: 16) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        let wasLiked = comment.isLiked
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            toggleCommentLike(commentDbId: comment.dbId, wasLiked: wasLiked)
                        }
                        generator.impactOccurred()
                        if let commentDbId = comment.dbId {
                            Task {
                                let service = NookService()
                                if wasLiked {
                                    try? await service.unlikeComment(commentId: commentDbId)
                                } else {
                                    try? await service.likeComment(commentId: commentDbId)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(comment.isLiked ? "heart-fill" : "heart")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 14, height: 14)

                            if comment.likes > 0 {
                                Text("\(comment.likes)")
                                    .font(NookFont.caption)
                            }
                        }
                        .foregroundStyle(
                            comment.isLiked
                                ? Color.nook.clubDetailLikeActive
                                : Color.nook.detailMeta
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            replyingToName = comment.authorName
                            replyingToId = comment.dbId
                        }
                        isCommentFocused = true
                    } label: {
                        Text("Reply")
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.detailMeta)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 24 + indent)
        .padding(.trailing, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            if let replyTo = replyingToName {
                HStack {
                    Text("Replying to \(replyTo)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            replyingToName = nil
                            replyingToId = nil
                        }
                    } label: {
                        Image("x-bold")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Color.nook.detailMeta)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.nook.mutedForeground)
                    )

                TextField(
                    replyingToName != nil ? "Reply..." : "Add a comment...",
                    text: $commentText,
                    axis: .vertical
                )
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.detailTitle)
                .lineLimit(1...5)
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit { sendComment() }

                if !commentText.isEmpty {
                    Button {
                        sendComment()
                    } label: {
                        Image("arrow-up-bold")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.nook.primary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.easeOut(duration: 0.2), value: commentText.isEmpty)
        }
        .background(Color.nook.detailBackground)
    }

    // MARK: - Comment Actions

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parentId = replyingToId
        commentText = ""
        replyingToName = nil
        replyingToId = nil
        isCommentFocused = false

        guard let dbId = nook.dbId else { return }
        Task {
            let service = NookService()
            try? await service.addComment(nookId: dbId, body: text, parentCommentId: parentId)
            await reloadComments()
        }
    }

    private func toggleCommentLike(commentDbId: UUID?, wasLiked: Bool) {
        guard let dbId = commentDbId else { return }
        toggleCommentLikeRecursive(in: &comments, dbId: dbId, wasLiked: wasLiked)
    }

    private func toggleCommentLikeRecursive(in list: inout [NookComment], dbId: UUID, wasLiked: Bool) {
        for i in list.indices {
            if list[i].dbId == dbId {
                list[i].isLiked.toggle()
                list[i].likes += wasLiked ? -1 : 1
                return
            }
            toggleCommentLikeRecursive(in: &list[i].replies, dbId: dbId, wasLiked: wasLiked)
        }
    }

    private func toggleCollapsed(commentDbId: UUID?) {
        guard let dbId = commentDbId else { return }
        toggleCollapsedRecursive(in: &comments, dbId: dbId)
    }

    private func toggleCollapsedRecursive(in list: inout [NookComment], dbId: UUID) {
        for i in list.indices {
            if list[i].dbId == dbId {
                list[i].isCollapsed.toggle()
                return
            }
            toggleCollapsedRecursive(in: &list[i].replies, dbId: dbId)
        }
    }

    private func reloadComments() async {
        guard let dbId = nook.dbId else { return }
        let service = NookService()
        guard let dbComments = try? await service.getComments(nookId: dbId) else { return }

        let likedIds = (try? await service.getLikedCommentIds(nookId: dbId)) ?? []

        var commentById: [UUID: NookComment] = [:]
        for c in dbComments {
            commentById[c.id] = NookComment(
                dbId: c.id,
                userId: c.userId,
                authorName: c.authorName,
                authorAvatarURL: c.authorAvatarURL,
                createdAt: c.createdAt,
                body: c.body,
                likes: c.likesCount,
                isLiked: likedIds.contains(c.id)
            )
        }

        var childrenOf: [UUID: [UUID]] = [:]
        var rootIds: [UUID] = []

        for c in dbComments {
            if let parentId = c.parentCommentId {
                childrenOf[parentId, default: []].append(c.id)
            } else {
                rootIds.append(c.id)
            }
        }

        func buildTree(id: UUID) -> NookComment? {
            guard var comment = commentById[id] else { return nil }
            if let childIds = childrenOf[id] {
                comment.replies = childIds.compactMap { buildTree(id: $0) }
            }
            return comment
        }

        var tree = rootIds.compactMap { buildTree(id: $0) }
        sortTopLevel(&tree)
        collapseAfterTop(&tree, visibleCount: Self.defaultVisibleReplies)

        withAnimation(.easeOut(duration: 0.25)) {
            comments = tree
        }
    }

    private func sortTopLevel(_ list: inout [NookComment]) {
        let comparator: (NookComment, NookComment) -> Bool = {
            switch sortOrder {
            case .top: return { ($0.likes + $0.replies.count) > ($1.likes + $1.replies.count) }
            case .newest: return { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            case .oldest: return { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            }
        }()
        list.sort(by: comparator)
    }

    private func collapseAfterTop(_ list: inout [NookComment], visibleCount: Int) {
        for i in list.indices {
            list[i].isCollapsed = list[i].replies.count > visibleCount
            collapseAfterTop(&list[i].replies, visibleCount: visibleCount)
        }
    }

    private func sortComments() {
        sortTopLevel(&comments)
        collapseAfterTop(&comments, visibleCount: Self.defaultVisibleReplies)
    }

    // MARK: - Delete

    private func deleteNook() {
        guard let dbId = nook.dbId else { return }
        Task {
            let service = NookService()
            try? await service.deleteNook(nookId: dbId)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            await MainActor.run {
                NotificationCenter.default.post(name: .nooksDidChange, object: nil)
                dismiss()
            }
        }
    }
}

// MARK: - Header Bar (glass on iOS 26, solid fallback)

private struct NookDetailHeaderBar<Bar: View>: ViewModifier {
    @ViewBuilder var bar: () -> Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                bar()
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                bar()
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .background(Color.nook.detailBackground)
            }
        }
    }
}
