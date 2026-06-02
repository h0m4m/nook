import SwiftUI

// MARK: - Comment Model

struct PostComment: Identifiable {
    let id: UUID
    let dbId: UUID?
    let userId: UUID?
    let authorName: String
    let authorAvatarURL: URL?
    let timeAgo: String
    let body: String
    var likes: Int
    var isLiked: Bool
    var replies: [PostComment]

    init(
        id: UUID = UUID(),
        dbId: UUID? = nil,
        userId: UUID? = nil,
        authorName: String,
        authorAvatarURL: URL? = nil,
        timeAgo: String,
        body: String,
        likes: Int = 0,
        isLiked: Bool = false,
        replies: [PostComment] = []
    ) {
        self.id = id
        self.dbId = dbId
        self.userId = userId
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.timeAgo = timeAgo
        self.body = body
        self.likes = likes
        self.isLiked = isLiked
        self.replies = replies
    }
}

// MARK: - Comment Sort

enum CommentSort: String, CaseIterable {
    case top, newest, oldest

    var label: String {
        switch self {
        case .top: "Top"
        case .newest: "Newest"
        case .oldest: "Oldest"
        }
    }
}

// MARK: - Post Detail View

struct PostDetailView: View {
    let post: ClubPost
    @Environment(\.dismiss) private var dismiss
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var commentText = ""
    @State private var comments: [PostComment]
    @FocusState private var isCommentFocused: Bool
    @State private var replyingToName: String?
    @State private var replyingToId: UUID?
    @State private var sortOrder: CommentSort = .top
    @State private var didLoad = false

    private let service = ClubService()

    init(post: ClubPost) {
        self.post = post
        self._isLiked = State(initialValue: post.isLiked)
        self._likeCount = State(initialValue: post.likesCount)
        // Mock comments only used in previews (no backing post id).
        self._comments = State(initialValue: post.dbId == nil ? Self.mockComments : [])
    }

    private var commentCount: Int {
        comments.reduce(0) { $0 + 1 + $1.replies.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    postContent
                    commentDivider
                    commentsSection
                }
            }
            .modifier(PostDetailSoftScrollEdge())

            replyBar
        }
        .background(Color.nook.clubDetailBackground)
        .modifier(
            PostDetailTopBar(
                onBack: { dismiss() },
                onReport: reportPost,
                onCopyLink: copyLink,
                onBlock: blockAuthor
            )
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .onTapGesture {
            isCommentFocused = false
        }
        .task {
            await loadPostData()
        }
    }

    private func loadPostData() async {
        guard let dbId = post.dbId, !didLoad else { return }
        didLoad = true

        if let liked = try? await service.isPostLiked(postId: dbId) {
            isLiked = liked
        }

        async let commentsResult = try? service.getComments(postId: dbId)
        async let likedResult = try? service.getLikedCommentIds(postId: dbId)

        let loaded = (await commentsResult) ?? []
        let likedIds = (await likedResult) ?? []

        comments = Self.buildTree(from: loaded, likedIds: likedIds)
        sortComments()
    }

    /// Build a two-level comment tree: top-level comments with their (flattened) descendants as replies.
    private static func buildTree(from models: [ClubCommentModel], likedIds: Set<UUID>) -> [PostComment] {
        func node(_ m: ClubCommentModel) -> PostComment {
            PostComment(
                id: m.id,
                dbId: m.id,
                userId: m.userId,
                authorName: m.authorName,
                authorAvatarURL: m.authorAvatarURL,
                timeAgo: m.createdAt.clubRelativeShort,
                body: m.body,
                likes: m.likesCount,
                isLiked: likedIds.contains(m.id)
            )
        }

        let byId = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })

        func root(of id: UUID) -> UUID {
            var current = id
            while let parent = byId[current]?.parentCommentId, byId[parent] != nil {
                current = parent
            }
            return current
        }

        let topLevel = models.filter { $0.parentCommentId == nil }
        return topLevel.map { top in
            var comment = node(top)
            comment.replies = models
                .filter { $0.parentCommentId != nil && root(of: $0.id) == top.id }
                .sorted { $0.createdAt < $1.createdAt }
                .map { node($0) }
            return comment
        }
    }
}

// MARK: - Post Content (full post displayed at top)

private extension PostDetailView {
    var postContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header
            HStack(spacing: 12) {
                ClubAvatarView(url: post.authorAvatarURL, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    Text(post.timeAgo)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            // Post body
            postBodyText
                .padding(.top, 14)
                .padding(.horizontal, 20)

            // Poll
            if let pollModel = post.pollModel {
                ClubPollVoteView(poll: pollModel)
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }

            // Post image(s)
            if !post.imageURLs.isEmpty {
                postImages
                    .padding(.top, 14)
            } else if post.imageName != nil || post.placeholderColor != nil {
                legacyPostImage
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }

            // Interaction bar
            interactionBar
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    var postBodyText: some View {
        Group {
            if post.boldRanges.isEmpty {
                Text(post.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineSpacing(5)
            } else {
                styledPostText(post.body, boldRanges: post.boldRanges)
                    .lineSpacing(5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func styledPostText(_ text: String, boldRanges: [String]) -> Text {
        var result = Text("")
        var remaining = text

        for boldText in boldRanges {
            if let range = remaining.range(of: boldText) {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    result = result + Text(before)
                        .font(NookFont.labelMediumSmall)
                        .foregroundColor(Color.nook.clubDetailTitle)
                }
                result = result + Text(boldText)
                    .font(NookFont.labelBoldSmall)
                    .foregroundColor(Color.nook.clubDetailJoinedButton)
                remaining = String(remaining[range.upperBound...])
            }
        }

        if !remaining.isEmpty {
            result = result + Text(remaining)
                .font(NookFont.labelMediumSmall)
                .foregroundColor(Color.nook.clubDetailTitle)
        }

        return result
    }

    var postImages: some View {
        Group {
            if post.imageURLs.count == 1, let url = post.imageURLs.first {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color.nook.secondary
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.imageURLs, id: \.self) { url in
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image): image.resizable().scaledToFill()
                                default: Color.nook.secondary
                                }
                            }
                            .frame(width: 280, height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    var legacyPostImage: some View {
        Group {
            if let color = post.placeholderColor {
                color
            } else if let imageName = post.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
    }

    var interactionBar: some View {
        HStack(spacing: 0) {
            // Like
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                let wasLiked = isLiked
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }
                generator.impactOccurred()

                if let dbId = post.dbId {
                    Task {
                        if wasLiked {
                            try? await service.unlikePost(postId: dbId)
                        } else {
                            try? await service.likePost(postId: dbId)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(isLiked ? "heart-fill" : "heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)
                        .scaleEffect(isLiked ? 1.15 : 1.0)

                    Text(ClubPost.formatCount(max(likeCount, 0)))
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)
                }
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(width: 24)

            // Comment count
            HStack(spacing: 6) {
                Image("chat-circle")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text("\(commentCount)")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }

            Spacer()

            // Share
            ShareLink(item: shareURL) {
                Image("share-network")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }
        }
    }

    var shareURL: URL {
        if let dbId = post.dbId {
            return URL(string: "https://nook.app/post/\(dbId.uuidString)") ?? URL(string: "https://nook.app")!
        }
        return URL(string: "https://nook.app")!
    }
}

// MARK: - Comment Divider

private extension PostDetailView {
    var commentDivider: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            HStack {
                Text("\(commentCount) Comments")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)

                Spacer()

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
                    .foregroundStyle(Color.nook.clubDetailMeta)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Comments Section

private extension PostDetailView {
    var commentsSection: some View {
        LazyVStack(spacing: 0) {
            if comments.isEmpty {
                Text("No comments yet. Start the conversation.")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding(.horizontal, 24)
            } else {
                ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                    VStack(spacing: 0) {
                        commentRow(comment, depth: 0, index: index)

                        ForEach(Array(comment.replies.enumerated()), id: \.element.id) { replyIndex, reply in
                            commentRow(reply, depth: 1, index: index, replyIndex: replyIndex)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 40)
    }

    func commentRow(_ comment: PostComment, depth: Int, index: Int, replyIndex: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.nook.detailTabBorder)
                    .frame(width: 2)
                    .padding(.leading, 36)
            }

            ClubAvatarView(url: comment.authorAvatarURL, size: depth == 0 ? 36 : 28)

            VStack(alignment: .leading, spacing: 6) {
                // Name + time
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    Text(comment.timeAgo)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }

                // Body
                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineSpacing(4)

                // Actions
                HStack(spacing: 16) {
                    // Like
                    Button {
                        toggleCommentLike(index: index, replyIndex: replyIndex)
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
                        .foregroundStyle(comment.isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)
                    }
                    .buttonStyle(.plain)

                    // Reply
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            replyingToName = comment.authorName
                            replyingToId = comment.dbId
                        }
                        isCommentFocused = true
                    } label: {
                        Text("Reply")
                            .font(NookFont.captionBold)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    func toggleCommentLike(index: Int, replyIndex: Int?) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        var commentId: UUID?
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if let ri = replyIndex {
                comments[index].replies[ri].isLiked.toggle()
                let liked = comments[index].replies[ri].isLiked
                comments[index].replies[ri].likes += liked ? 1 : -1
                comments[index].replies[ri].likes = max(comments[index].replies[ri].likes, 0)
                commentId = comments[index].replies[ri].dbId
            } else {
                comments[index].isLiked.toggle()
                let liked = comments[index].isLiked
                comments[index].likes += liked ? 1 : -1
                comments[index].likes = max(comments[index].likes, 0)
                commentId = comments[index].dbId
            }
        }
        generator.impactOccurred()

        guard let commentId else { return }
        let nowLiked = replyIndex != nil ? comments[index].replies[replyIndex!].isLiked : comments[index].isLiked
        Task {
            if nowLiked {
                try? await service.likeComment(commentId: commentId)
            } else {
                try? await service.unlikeComment(commentId: commentId)
            }
        }
    }
}

// MARK: - Reply Bar

private extension PostDetailView {
    var replyBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            if let replyTo = replyingToName {
                HStack {
                    Text("Replying to \(replyTo)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)

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
                            .foregroundStyle(Color.nook.clubDetailMeta)
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
                .foregroundStyle(Color.nook.clubDetailTitle)
                .lineLimit(1...5)
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendComment()
                }

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
                            .background(Color.nook.clubDetailJoinedButton, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.easeOut(duration: 0.2), value: commentText.isEmpty)
        }
        .background(Color.nook.clubDetailBackground)
    }

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parentId = replyingToId
        let newComment = PostComment(
            authorName: "You",
            timeAgo: "now",
            body: text
        )

        withAnimation(.easeOut(duration: 0.25)) {
            if let parentId,
               let topIndex = comments.firstIndex(where: { $0.dbId == parentId || $0.replies.contains(where: { $0.dbId == parentId }) }) {
                comments[topIndex].replies.append(newComment)
            } else {
                comments.insert(newComment, at: 0)
            }
            commentText = ""
            replyingToName = nil
            replyingToId = nil
        }

        isCommentFocused = false

        if let dbId = post.dbId {
            Task {
                try? await service.addComment(postId: dbId, body: text, parentCommentId: parentId)
            }
        }
    }

    private func sortComments() {
        switch sortOrder {
        case .top:
            comments.sort { $0.likes > $1.likes }
        case .newest:
            comments.sort { sortValue($0.timeAgo) < sortValue($1.timeAgo) }
        case .oldest:
            comments.sort { sortValue($0.timeAgo) > sortValue($1.timeAgo) }
        }
    }

    private func sortValue(_ timeAgo: String) -> Int {
        if timeAgo == "now" { return 0 }
        let parts = timeAgo.split(separator: " ").first.map(String.init) ?? timeAgo
        let trimmed = parts
        let number = Int(trimmed.prefix { $0.isNumber }) ?? 0
        let unit = trimmed.drop { $0.isNumber }
        switch unit {
        case "m": return number
        case "h": return number * 60
        case "d": return number * 1440
        case "w": return number * 10080
        default: return 99999
        }
    }
}

// MARK: - Actions (moderation / share)

private extension PostDetailView {
    func reportPost() {
        guard let dbId = post.dbId else { return }
        Task { try? await service.report(targetType: "post", targetId: dbId, reason: nil) }
    }

    func copyLink() {
        UIPasteboard.general.url = shareURL
    }

    func blockAuthor() {
        guard let userId = post.userId else { return }
        Task { try? await service.blockUser(userId: userId) }
        dismiss()
    }
}

// MARK: - Top Bar

private struct PostDetailTopBar: ViewModifier {
    let onBack: () -> Void
    let onReport: () -> Void
    let onCopyLink: () -> Void
    let onBlock: () -> Void

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
                    .background(Color.nook.clubDetailBackground)
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
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())

            Text("Post")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Spacer()

            Menu {
                Button(role: .destructive, action: onReport) {
                    Label {
                        Text("Report")
                            .font(.subheadline)
                    } icon: {
                        Image("flag")
                            .renderingMode(.template)
                    }
                }

                Button(action: onCopyLink) {
                    Label {
                        Text("Copy link")
                            .font(.subheadline)
                    } icon: {
                        Image("link")
                            .renderingMode(.template)
                    }
                }

                Button(role: .destructive, action: onBlock) {
                    Label {
                        Text("Block user")
                            .font(.subheadline)
                    } icon: {
                        Image("user-minus")
                            .renderingMode(.template)
                    }
                }
            } label: {
                Image("dots-three-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.clubDetailMeta)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Scroll Edge

private struct PostDetailSoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

// MARK: - Mock Comments (previews only)

extension PostDetailView {
    static let mockComments: [PostComment] = [
        PostComment(
            authorName: "Kai Tanaka",
            timeAgo: "1h",
            body: "The sky kingdom arc is incredible. Episode 10 had me in tears. The manga goes way beyond this arc and it only gets better.",
            likes: 42,
            replies: [
                PostComment(
                    authorName: "Maya Lin",
                    timeAgo: "45m",
                    body: "That's great to hear! I'll definitely pick up the manga after the season ends.",
                    likes: 8
                ),
                PostComment(
                    authorName: "Riku Ota",
                    timeAgo: "30m",
                    body: "Start from chapter 48 if you want to continue from where the anime is right now.",
                    likes: 15
                ),
            ]
        ),
        PostComment(
            authorName: "Sophia Chen",
            timeAgo: "1h",
            body: "The art direction team deserves all the awards this year. Every single frame in the sky kingdom is wallpaper material.",
            likes: 67
        ),
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PostDetailView(
            post: ClubPost(
                authorName: "Maya Lin",
                timeAgo: "2h",
                body: "Just finished episode 12 of The Cloud Weaver and I'm completely blown away.",
                boldRanges: ["The Cloud Weaver"],
                placeholderColor: Color(hex: 0x87CEEB).opacity(0.6),
                likes: "1.2k",
                comments: "84"
            )
        )
    }
}
