import SwiftUI
import Supabase

/// A menu row label. Icon sizing is normalized at the asset level (the SVG
/// viewBoxes are padded so every glyph fills the same proportion), because
/// UIKit ignores SwiftUI frame sizing on menu icons.
@ViewBuilder
func sizedMenuLabel(_ title: String, icon: String, size: CGFloat = 17) -> some View {
    Label(title, image: icon)
}

// MARK: - Club Post Comment Model
// Mirrors ReviewComment / NookComment so club posts behave identically.

struct ClubPostComment: Identifiable, Hashable {
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
    var replies: [ClubPostComment]

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
        replies: [ClubPostComment] = []
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
    @State private var comments: [ClubPostComment]
    @FocusState private var isCommentFocused: Bool
    @State private var replyingToName: String?
    @State private var replyingToId: UUID?
    @State private var sortOrder: CommentSort = .top
    @State private var currentUserId: UUID?
    @State private var viewerRole: String?
    @State private var isPinned: Bool
    @State private var didLoad = false

    private let service = ClubService()

    init(post: ClubPost) {
        self.post = post
        self._isLiked = State(initialValue: post.isLiked)
        self._likeCount = State(initialValue: post.likesCount)
        self._isPinned = State(initialValue: post.isPinned)
        // Mock comments only render in previews (no backing post id).
        self._comments = State(initialValue: post.dbId == nil ? Self.mockComments : [])
    }

    private var accent: Color { post.accentColor }

    private var commentCount: Int {
        comments.reduce(0) { $0 + 1 + totalReplyCount($1) }
    }

    private var canModerate: Bool { viewerRole == "owner" || viewerRole == "admin" }
    private var canDelete: Bool { canModerate || (post.userId != nil && post.userId == currentUserId) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    postContent
                    commentDivider
                    commentsSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(PostDetailSoftScrollEdge())

            replyBar
        }
        .background(Color.nook.clubDetailBackground)
        .modifier(
            PostDetailTopBar(
                isPinned: isPinned,
                canModerate: canModerate,
                canDelete: canDelete,
                accent: accent,
                onBack: { dismiss() },
                onReport: reportPost,
                onBlock: blockAuthor,
                onTogglePin: togglePin,
                onDelete: deletePost
            )
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .navigationDestination(for: ClubPostComment.self) { comment in
            ClubCommentThreadView(root: comment, accent: accent)
        }
        .onTapGesture { isCommentFocused = false }
        .task { await loadData() }
    }

    private func loadData() async {
        guard let dbId = post.dbId, !didLoad else { return }
        didLoad = true

        currentUserId = try? await supabase.auth.session.user.id

        if let clubId = post.clubId {
            viewerRole = (try? await service.getMyMembership(clubId: clubId))?.role
        }

        if let liked = try? await service.isPostLiked(postId: dbId) {
            isLiked = liked
        }

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

    private func totalReplyCount(_ comment: ClubPostComment) -> Int {
        comment.replies.reduce(0) { $0 + 1 + totalReplyCount($1) }
    }
}

// MARK: - Post Content

private extension PostDetailView {
    var postContent: some View {
        VStack(alignment: .leading, spacing: 0) {
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

                if isPinned {
                    HStack(spacing: 4) {
                        Image("push-pin-fill")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                        Text("Pinned")
                            .font(NookFont.captionBold)
                    }
                    .foregroundStyle(accent)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            Text(post.body)
                .font(NookFont.labelMediumSmall)
                .foregroundStyle(Color.nook.clubDetailTitle)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
                .padding(.horizontal, 20)

            if let pollModel = post.pollModel {
                ClubPollVoteView(poll: pollModel, accent: accent)
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }

            if !post.imageURLs.isEmpty {
                postImages
                    .padding(.top, 14)
            } else if post.imageName != nil || post.placeholderColor != nil {
                legacyPostImage
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
            }

            interactionBar
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
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
                Image(imageName).resizable().scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))
    }

    var interactionBar: some View {
        HStack(spacing: 0) {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                let wasLiked = isLiked
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                    likeCount = max(likeCount + (isLiked ? 1 : -1), 0)
                }
                generator.impactOccurred()
                if let dbId = post.dbId {
                    Task {
                        if wasLiked { try? await service.unlikePost(postId: dbId) }
                        else { try? await service.likePost(postId: dbId) }
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

                    Text(ClubPost.formatCount(likeCount))
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)
                }
            }
            .buttonStyle(.plain)

            Spacer().frame(width: 24)

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
                                if sortOrder == sort { Image(systemName: "checkmark") }
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

// MARK: - Comments Section (threaded, collapsible — same as reviews/nooks)

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
                ForEach(comments) { comment in
                    renderCommentTree(comment, depth: 0)
                }
            }
        }
        .padding(.bottom, 40)
    }

    static let defaultVisibleReplies = 2
    static let maxDepth = 3

    func engagement(_ c: ClubPostComment) -> Int { c.likes + c.replies.count }

    func renderCommentTree(_ comment: ClubPostComment, depth: Int) -> AnyView {
        if depth >= Self.maxDepth {
            return AnyView(
                VStack(spacing: 0) {
                    commentRow(comment, depth: Self.maxDepth)

                    if !comment.replies.isEmpty {
                        NavigationLink(value: comment) {
                            HStack(spacing: 6) {
                                Rectangle().fill(accent).frame(width: 2, height: 12)
                                Text("Continue this thread →")
                                    .font(NookFont.captionBold)
                                    .foregroundStyle(accent)
                            }
                            .padding(.leading, 24 + CGFloat(Self.maxDepth + 1) * 24)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            )
        }

        let topReplies = comment.replies.sorted { engagement($0) > engagement($1) }
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
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { toggleCollapsed(commentDbId: comment.dbId) }
                    } label: {
                        threadLink("View \(totalHidden) more \(totalHidden == 1 ? "reply" : "replies")", depth: depth)
                    }
                    .buttonStyle(.plain)
                }

                if !comment.isCollapsed && comment.replies.count > Self.defaultVisibleReplies {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { toggleCollapsed(commentDbId: comment.dbId) }
                    } label: {
                        threadLink("Hide replies", depth: depth, muted: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    func threadLink(_ text: String, depth: Int, muted: Bool = false) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.nook.detailTabBorder).frame(width: 2, height: 12)
            Text(text)
                .font(NookFont.captionBold)
                .foregroundStyle(muted ? Color.nook.clubDetailMeta : accent)
        }
        .padding(.leading, 24 + CGFloat(depth + 1) * 24)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func commentRow(_ comment: ClubPostComment, depth: Int) -> some View {
        let indent = CGFloat(min(depth, Self.maxDepth)) * 24
        return HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle().fill(Color.nook.detailTabBorder).frame(width: 2)
            }

            ClubAvatarView(url: comment.authorAvatarURL, size: depth == 0 ? 36 : 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailTitle)

                    if let date = comment.createdAt {
                        Text(relativeTime(from: date))
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                }

                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineSpacing(4)

                HStack(spacing: 16) {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        let wasLiked = comment.isLiked
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            toggleLike(commentDbId: comment.dbId, wasLiked: wasLiked)
                        }
                        generator.impactOccurred()
                        if let commentDbId = comment.dbId {
                            Task {
                                if wasLiked { try? await service.unlikeComment(commentId: commentDbId) }
                                else { try? await service.likeComment(commentId: commentDbId) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(comment.isLiked ? "heart-fill" : "heart")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 14, height: 14)

                            if comment.likes > 0 {
                                Text("\(comment.likes)").font(NookFont.caption)
                            }
                        }
                        .foregroundStyle(comment.isLiked ? Color.nook.clubDetailLikeActive : Color.nook.clubDetailMeta)
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
                            .foregroundStyle(Color.nook.clubDetailMeta)
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

    func toggleCollapsed(commentDbId: UUID?) {
        guard let dbId = commentDbId else { return }
        toggleCollapsedRecursive(in: &comments, dbId: dbId)
    }

    func toggleCollapsedRecursive(in list: inout [ClubPostComment], dbId: UUID) {
        for i in list.indices {
            if list[i].dbId == dbId { list[i].isCollapsed.toggle(); return }
            toggleCollapsedRecursive(in: &list[i].replies, dbId: dbId)
        }
    }
}

// MARK: - Reply Bar

private extension PostDetailView {
    var replyBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.nook.detailTabBorder).frame(height: 1)

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
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .transition(.opacity)
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
                            .background(accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .animation(.easeOut(duration: 0.2), value: commentText.isEmpty)
        }
        .background(Color.nook.clubDetailBackground)
    }

    func toggleLike(commentDbId: UUID?, wasLiked: Bool) {
        guard let dbId = commentDbId else { return }
        toggleLikeRecursive(in: &comments, dbId: dbId, wasLiked: wasLiked)
    }

    func toggleLikeRecursive(in list: inout [ClubPostComment], dbId: UUID, wasLiked: Bool) {
        for i in list.indices {
            if list[i].dbId == dbId {
                list[i].isLiked.toggle()
                list[i].likes = max(list[i].likes + (wasLiked ? -1 : 1), 0)
                return
            }
            toggleLikeRecursive(in: &list[i].replies, dbId: dbId, wasLiked: wasLiked)
        }
    }

    func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parentId = replyingToId
        commentText = ""
        replyingToName = nil
        replyingToId = nil
        isCommentFocused = false

        guard let dbId = post.dbId else { return }
        Task {
            try? await service.addComment(postId: dbId, body: text, parentCommentId: parentId)
            await reloadComments()
        }
    }

    func reloadComments() async {
        guard let dbId = post.dbId else { return }
        guard let dbComments = try? await service.getComments(postId: dbId) else { return }
        let likedIds = (try? await service.getLikedCommentIds(postId: dbId)) ?? []

        var commentById: [UUID: ClubPostComment] = [:]
        for c in dbComments {
            commentById[c.id] = ClubPostComment(
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

        func buildTree(id: UUID) -> ClubPostComment? {
            guard var comment = commentById[id] else { return nil }
            if let childIds = childrenOf[id] {
                comment.replies = childIds.compactMap { buildTree(id: $0) }
            }
            return comment
        }

        var tree = rootIds.compactMap { buildTree(id: $0) }
        sortTopLevel(&tree)
        collapseAfterTop(&tree, visibleCount: Self.defaultVisibleReplies)

        withAnimation(.easeOut(duration: 0.25)) { comments = tree }
    }

    func sortTopLevel(_ list: inout [ClubPostComment]) {
        let comparator: (ClubPostComment, ClubPostComment) -> Bool = {
            switch sortOrder {
            case .top: return { ($0.likes + $0.replies.count) > ($1.likes + $1.replies.count) }
            case .newest: return { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            case .oldest: return { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            }
        }()
        list.sort(by: comparator)
    }

    func collapseAfterTop(_ list: inout [ClubPostComment], visibleCount: Int) {
        for i in list.indices {
            list[i].isCollapsed = list[i].replies.count > visibleCount
            collapseAfterTop(&list[i].replies, visibleCount: visibleCount)
        }
    }

    func sortComments() {
        sortTopLevel(&comments)
        collapseAfterTop(&comments, visibleCount: Self.defaultVisibleReplies)
    }
}

// MARK: - Moderation actions

private extension PostDetailView {
    func reportPost() {
        guard let dbId = post.dbId else { return }
        Task { try? await service.report(targetType: "post", targetId: dbId, reason: nil) }
    }

    func blockAuthor() {
        guard let userId = post.userId else { return }
        Task { try? await service.blockUser(userId: userId) }
        dismiss()
    }

    func togglePin() {
        guard let dbId = post.dbId else { return }
        let newValue = !isPinned
        isPinned = newValue
        Task { try? await service.setPinned(postId: dbId, pinned: newValue) }
    }

    func deletePost() {
        guard let dbId = post.dbId else { return }
        Task { try? await service.deletePost(postId: dbId) }
        dismiss()
    }
}

// MARK: - Top Bar

private struct PostDetailTopBar: ViewModifier {
    let isPinned: Bool
    let canModerate: Bool
    let canDelete: Bool
    let accent: Color
    let onBack: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                topBarContent.padding(.top, 4).padding(.bottom, 4)
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                topBarContent
                    .background(Color.nook.clubDetailBackground)
                    .padding(.top, 4).padding(.bottom, 4)
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
                if canModerate {
                    Button(action: onTogglePin) {
                        sizedMenuLabel(isPinned ? "Unpin" : "Pin to club", icon: "push-pin")
                    }
                }
                Button(role: .destructive, action: onReport) {
                    sizedMenuLabel("Report", icon: "flag")
                }
                Button(action: onBlock) {
                    sizedMenuLabel("Block user", icon: "user-minus")
                }
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        sizedMenuLabel("Delete post", icon: "trash")
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

// MARK: - Comment Thread View (Continue this thread)

struct ClubCommentThreadView: View {
    let root: ClubPostComment
    var accent: Color = Color.nook.clubDetailJoinedButton
    @Environment(\.dismiss) private var dismiss

    private static let maxDepth = 3

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                renderTree(root, depth: 0)
            }
            .padding(.bottom, 40)
        }
        .background(Color.nook.clubDetailBackground)
        .modifier(ThreadTopBar(onBack: { dismiss() }))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .navigationDestination(for: ClubPostComment.self) { comment in
            ClubCommentThreadView(root: comment, accent: accent)
        }
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    private func renderTree(_ comment: ClubPostComment, depth: Int) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                commentCell(comment, depth: min(depth, Self.maxDepth))
                ForEach(comment.replies) { reply in
                    renderTree(reply, depth: depth + 1)
                }
            }
        )
    }

    private func commentCell(_ comment: ClubPostComment, depth: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle().fill(Color.nook.detailTabBorder).frame(width: 2)
            }
            ClubAvatarView(url: comment.authorAvatarURL, size: depth == 0 ? 36 : 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.clubDetailTitle)
                    if let date = comment.createdAt {
                        Text(relativeTime(from: date))
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                }
                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .lineSpacing(4)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 24 + CGFloat(depth) * 24)
        .padding(.trailing, 24)
        .padding(.vertical, 12)
    }
}

private struct ThreadTopBar: ViewModifier {
    let onBack: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) { bar.padding(.vertical, 4) }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                bar.background(Color.nook.clubDetailBackground).padding(.vertical, 4)
            }
        }
    }

    private var bar: some View {
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

            Text("Thread")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.clubDetailTitle)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Mock Comments (previews only)

extension PostDetailView {
    static let mockComments: [ClubPostComment] = [
        ClubPostComment(
            authorName: "Kai Tanaka",
            createdAt: Date().addingTimeInterval(-3600),
            body: "The sky kingdom arc is incredible. The manga goes way beyond this and only gets better.",
            likes: 42,
            isCollapsed: false,
            replies: [
                ClubPostComment(authorName: "Maya Lin", createdAt: Date().addingTimeInterval(-2700), body: "I'll pick up the manga after the season ends.", likes: 8),
                ClubPostComment(authorName: "Riku Ota", createdAt: Date().addingTimeInterval(-1800), body: "Start from chapter 48 to continue where the anime is.", likes: 15),
            ]
        ),
        ClubPostComment(
            authorName: "Sophia Chen",
            createdAt: Date().addingTimeInterval(-3000),
            body: "The art direction team deserves every award this year.",
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
                likes: "1.2k",
                comments: "84",
                likesCount: 1200
            )
        )
    }
}
