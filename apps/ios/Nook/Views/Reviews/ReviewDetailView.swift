import SwiftUI
import Supabase

/// Parse a Markdown string into an `AttributedString`, falling back to plain text.
func markdownAttributed(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
}

// MARK: - Review Comment Model

struct ReviewComment: Identifiable, Hashable {
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
    var replies: [ReviewComment]

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
        replies: [ReviewComment] = []
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

// MARK: - Review Detail View

struct ReviewDetailView: View {
    let review: ReviewItem
    @Environment(\.dismiss) private var dismiss
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var commentText = ""
    @State private var comments: [ReviewComment]
    @FocusState private var isCommentFocused: Bool
    @State private var replyingToName: String?
    @State private var replyingToId: UUID?
    @State private var sortOrder: CommentSort = .top
    @State private var currentUserId: UUID?
    @State private var showReportConfirmation = false
    @State private var moderationError: String?
    @State private var showReportSheet = false
    private let moderation = ModerationService()

    init(review: ReviewItem) {
        self.review = review
        self._likeCount = State(initialValue: Int(review.likes) ?? 0)
        self._comments = State(initialValue: [])
    }

    private var canDelete: Bool {
        guard let authorId = review.reviewerUserId, let me = currentUserId else { return false }
        return authorId == me
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    reviewContent
                    commentDivider
                    commentsSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(ReviewDetailSoftScrollEdge())

            replyBar
        }
        .background(Color.nook.reviewDetailBackground)
        .modifier(
            ReviewDetailTopBar(
                onBack: { dismiss() },
                canDelete: canDelete,
                onDelete: deleteReview,
                onReport: reportReview,
                onBlock: blockReviewAuthor
            )
        )
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(subject: "review") { reason, details in
                submitReport(reason: reason, details: details)
            }
        }
        .alert("Report received", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for helping keep Nook safe. We'll review this.")
        }
        .alert("Comment not posted", isPresented: Binding(
            get: { moderationError != nil },
            set: { if !$0 { moderationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(moderationError ?? "")
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .navigationDestination(for: ReviewComment.self) { comment in
            CommentThreadView(root: comment)
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        guard let dbId = review.dbId else { return }
        let service = ReviewService()

        currentUserId = try? await supabase.auth.session.user.id

        // Check if liked
        isLiked = (try? await service.isReviewLiked(reviewId: dbId)) ?? false

        // Load comments from DB
        await reloadComments()
    }

    private func deleteReview() {
        guard let dbId = review.dbId else { return }
        Task { try? await ReviewService().deleteReview(reviewId: dbId) }
        dismiss()
    }

    /// Plain-text share payload. We don't have a web app, so sharing a URL would
    /// just produce a dead link — share a readable description instead.
    private var shareText: String {
        let title = review.title.isEmpty ? review.mediaTitle : "\(review.title) — \(review.mediaTitle)"
        return "\(review.reviewerName)'s review of \(title) on Nook"
    }

    private func reportReview() {
        guard review.dbId != nil else { return }
        showReportSheet = true
    }

    private func submitReport(reason: ReportReason, details: String?) {
        guard let dbId = review.dbId else { return }
        Task {
            try? await moderation.report(
                targetType: "review",
                targetId: dbId,
                reportedUserId: review.reviewerUserId,
                reason: reason,
                details: details
            )
        }
        showReportConfirmation = true
    }

    private func blockReviewAuthor() {
        guard let userId = review.reviewerUserId else { return }
        // Defer dismiss past the menu close (synchronous dismiss in a Menu action
        // is swallowed while the menu is still dismissing).
        Task { @MainActor in
            await BlockStore.shared.block(userId: userId)
            dismiss()
        }
    }
    private func ratingLabel(for rating: Double) -> String {
        ProfileReviewCard.ratingLabel(for: rating)
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
}

// MARK: - Review Content

private extension ReviewDetailView {
    var reviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header with rating
            reviewHeader
                .padding(.top, 20)
                .padding(.horizontal, 24)

            // Media context card
            if let route = review.mediaDetailRoute {
                NavigationLink(value: route) {
                    mediaContextCard
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .padding(.horizontal, 24)
            } else {
                mediaContextCard
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
            }

            // Review title
            Text(review.title)
                .font(NookFont.labelLarge)
                .foregroundStyle(Color.nook.reviewDetailTitle)
                .padding(.top, 20)
                .padding(.horizontal, 24)

            // Review body (supports Markdown formatting)
            Text(markdownAttributed(review.body))
                .font(NookFont.label)
                .foregroundStyle(Color.nook.reviewDetailBody)
                .lineSpacing(6)
                .padding(.top, 10)
                .padding(.horizontal, 24)

            // Interaction bar
            interactionBar
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
    }

    var reviewHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar + name — tappable to go to profile
            let profileLink: UserProfile? = review.reviewerUserId.map { userId in
                UserProfile(
                    id: userId.uuidString,
                    displayName: review.reviewerName,
                    username: "",
                    bio: "",
                    avatarURL: review.reviewerAvatarURL,
                    followersCount: 0,
                    followingCount: 0,
                    trackedMedia: 0,
                    reviewsWritten: 0,
                    curatedNooks: 0,
                    clubs: 0,
                    tasteIdentity: [],
                    recentActivity: [],
                    isCurrentUser: false
                )
            }

            if let profile = profileLink {
                NavigationLink(value: profile) {
                    reviewerInfo
                }
                .buttonStyle(.plain)
            } else {
                reviewerInfo
            }

            Spacer()

            // Rating badge
            HStack(spacing: 3) {
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.nook.detailRatingText)

                Text(ratingLabel(for: review.rating))
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.detailRatingText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.nook.detailRatingBadge)
            )
        }
    }

    private var reviewerInfo: some View {
        HStack(spacing: 12) {
            ReviewerAvatar(url: review.reviewerAvatarURL, size: 44, iconSize: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(review.reviewerName)
                        .font(NookFont.labelSmall)
                        .foregroundStyle(Color.nook.reviewDetailTitle)
                    UserPlusBadge(userId: review.reviewerUserId)
                }

                if let date = review.createdAt {
                    Text(relativeTime(from: date))
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.reviewDetailMeta)
                }
            }
        }
    }

    var mediaContextCard: some View {
        HStack(spacing: 12) {
            // Media poster
            Group {
                if let url = review.mediaImageURL {
                    CachedRemoteImage(url: url) { Color.nook.secondary }
                } else {
                    Color.nook.secondary
                        .overlay(
                            Image("reel")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Color.nook.mutedForeground)
                        )
                }
            }
            .frame(width: 48, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(review.mediaTitle)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.reviewDetailTitle)
                    .lineLimit(1)

                Text("View details")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.reviewDetailMeta)
            }

            Spacer()

            Image("caret-left-bold")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.nook.reviewDetailMeta)
                .rotationEffect(.degrees(180))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                        .strokeBorder(Color.nook.reviewDetailMediaCardBorder, lineWidth: 1)
                )
        )
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
                    likeCount += wasLiked ? -1 : 1
                }
                generator.impactOccurred()

                if let dbId = review.dbId {
                    Task {
                        let service = ReviewService()
                        if wasLiked {
                            try? await service.unlikeReview(reviewId: dbId)
                        } else {
                            try? await service.likeReview(reviewId: dbId)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(isLiked ? "heart-fill" : "heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(isLiked ? Color.nook.reviewDetailLikeActive : Color.nook.reviewDetailMeta)
                        .scaleEffect(isLiked ? 1.15 : 1.0)

                    Text("\(likeCount)")
                        .font(NookFont.labelBoldSmall)
                        .foregroundStyle(isLiked ? Color.nook.reviewDetailLikeActive : Color.nook.reviewDetailMeta)
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
                    .foregroundStyle(Color.nook.reviewDetailMeta)

                Text("\(comments.count)")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.reviewDetailMeta)
            }

            Spacer()

            // Share
            if FeatureFlags.shareEnabled {
                ShareLink(item: shareText) {
                    Image("share-network")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.nook.reviewDetailMeta)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Comment Divider

private extension ReviewDetailView {
    var commentDivider: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.reviewDetailDivider)
                .frame(height: 1)

            HStack {
                Text("\(comments.count) Comments")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.reviewDetailTitle)

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
                    .foregroundStyle(Color.nook.reviewDetailMeta)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Comments Section

private extension ReviewDetailView {
    var commentsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(comments) { comment in
                renderCommentTree(comment, depth: 0)
            }
        }
        .padding(.bottom, 40)
    }

    private static let defaultVisibleReplies = 2
    private static let maxDepth = 3

    private func engagement(_ c: ReviewComment) -> Int {
        c.likes + c.replies.count
    }

    private func renderCommentTree(_ comment: ReviewComment, depth: Int) -> AnyView {
        // At max depth, stop rendering children — show "Continue this thread"
        if depth >= Self.maxDepth {
            return AnyView(
                VStack(spacing: 0) {
                    commentRow(comment, depth: Self.maxDepth)

                    if !comment.replies.isEmpty {
                        NavigationLink(value: comment) {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color.nook.detailTabActive)
                                    .frame(width: 2, height: 12)

                                Text("Continue this thread →")
                                    .font(NookFont.captionBold)
                                    .foregroundStyle(Color.nook.detailTabActive)
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
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            toggleCollapsed(commentDbId: comment.dbId)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(Color.nook.reviewDetailDivider)
                                .frame(width: 2, height: 12)

                            Text("View \(totalHidden) more \(totalHidden == 1 ? "reply" : "replies")")
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.detailTabActive)
                        }
                        .padding(.leading, 24 + CGFloat(depth + 1) * 24)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                if !comment.isCollapsed && comment.replies.count > Self.defaultVisibleReplies {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            toggleCollapsed(commentDbId: comment.dbId)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(Color.nook.reviewDetailDivider)
                                .frame(width: 2, height: 12)

                            Text("Hide replies")
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.detailMeta)
                        }
                        .padding(.leading, 24 + CGFloat(depth + 1) * 24)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    @ViewBuilder
    private func commentAvatar(_ comment: ReviewComment, depth: Int) -> some View {
        let avatar = ReviewerAvatar(
            url: comment.authorAvatarURL,
            size: depth == 0 ? 36 : 28,
            iconSize: depth == 0 ? 14 : 11
        )

        if let profile = userProfile(for: comment) {
            NavigationLink(value: profile) { avatar }
                .buttonStyle(.plain)
        } else {
            avatar
        }
    }

    @ViewBuilder
    private func commentAuthorLink(_ comment: ReviewComment) -> some View {
        if let profile = userProfile(for: comment) {
            NavigationLink(value: profile) {
                HStack(spacing: 5) {
                    Text(comment.authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.reviewDetailTitle)
                    UserPlusBadge(userId: comment.userId)
                }
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 5) {
                Text(comment.authorName)
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.reviewDetailTitle)
                UserPlusBadge(userId: comment.userId)
            }
        }
    }

    private func userProfile(for comment: ReviewComment) -> UserProfile? {
        guard let userId = comment.userId else { return nil }
        return UserProfile(
            id: userId.uuidString,
            displayName: comment.authorName,
            username: "",
            bio: "",
            avatarURL: comment.authorAvatarURL,
            followersCount: 0,
            followingCount: 0,
            trackedMedia: 0,
            reviewsWritten: 0,
            curatedNooks: 0,
            clubs: 0,
            tasteIdentity: [],
            recentActivity: [],
            isCurrentUser: false
        )
    }

    private func totalReplyCount(_ comment: ReviewComment) -> Int {
        comment.replies.reduce(0) { $0 + 1 + totalReplyCount($1) }
    }

    private func toggleCollapsed(commentDbId: UUID?) {
        guard let dbId = commentDbId else { return }
        toggleCollapsedRecursive(in: &comments, dbId: dbId)
    }

    private func toggleCollapsedRecursive(in list: inout [ReviewComment], dbId: UUID) {
        for i in list.indices {
            if list[i].dbId == dbId {
                list[i].isCollapsed.toggle()
                return
            }
            toggleCollapsedRecursive(in: &list[i].replies, dbId: dbId)
        }
    }

    func commentRow(_ comment: ReviewComment, depth: Int) -> some View {
        let indent = CGFloat(min(depth, Self.maxDepth)) * 24
        return HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.nook.reviewDetailDivider)
                    .frame(width: 2)
            }

            commentAvatar(comment, depth: depth)

            VStack(alignment: .leading, spacing: 6) {
                // Name + time
                HStack(spacing: 6) {
                    commentAuthorLink(comment)

                    if let date = comment.createdAt {
                        Text(relativeTime(from: date))
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.reviewDetailMeta)
                    }
                }

                // Body
                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.reviewDetailTitle)
                    .lineSpacing(4)

                // Actions
                HStack(spacing: 16) {
                    // Like
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
                                let service = ReviewService()
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
                        .foregroundStyle(comment.isLiked ? Color.nook.reviewDetailLikeActive : Color.nook.reviewDetailMeta)
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
                            .foregroundStyle(Color.nook.reviewDetailMeta)
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
}

// MARK: - Reply Bar

private extension ReviewDetailView {
    var replyBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.reviewDetailDivider)
                .frame(height: 1)

            if let replyTo = replyingToName {
                HStack {
                    Text("Replying to \(replyTo)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.reviewDetailMeta)

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
                            .foregroundStyle(Color.nook.reviewDetailMeta)
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
                .foregroundStyle(Color.nook.reviewDetailTitle)
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
                            .background(Color.nook.primary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .animation(.easeOut(duration: 0.2), value: commentText.isEmpty)
        }
        .background(Color.nook.reviewDetailBackground)
    }

    private func toggleLike(commentDbId: UUID?, wasLiked: Bool) {
        guard let dbId = commentDbId else { return }
        for i in comments.indices {
            if comments[i].dbId == dbId {
                comments[i].isLiked.toggle()
                comments[i].likes += wasLiked ? -1 : 1
                return
            }
            for j in comments[i].replies.indices {
                if comments[i].replies[j].dbId == dbId {
                    comments[i].replies[j].isLiked.toggle()
                    comments[i].replies[j].likes += wasLiked ? -1 : 1
                    return
                }
                // Check deeper nesting
                toggleLikeRecursive(in: &comments[i].replies[j].replies, dbId: dbId, wasLiked: wasLiked)
            }
        }
    }

    private func toggleLikeRecursive(in replies: inout [ReviewComment], dbId: UUID, wasLiked: Bool) {
        for i in replies.indices {
            if replies[i].dbId == dbId {
                replies[i].isLiked.toggle()
                replies[i].likes += wasLiked ? -1 : 1
                return
            }
            toggleLikeRecursive(in: &replies[i].replies, dbId: dbId, wasLiked: wasLiked)
        }
    }

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parentId = replyingToId
        commentText = ""
        replyingToName = nil
        replyingToId = nil
        isCommentFocused = false

        guard let dbId = review.dbId else { return }
        Task {
            let service = ReviewService()
            do {
                try await service.addComment(reviewId: dbId, body: text, parentCommentId: parentId)
                await reloadComments()
            } catch {
                commentText = text
                moderationError = AppError(from: error).errorDescription
            }
        }
    }

    private func reloadComments() async {
        guard let dbId = review.dbId else { return }
        let service = ReviewService()
        guard let dbComments = try? await service.getComments(reviewId: dbId) else { return }

        // Load which comments the current user has liked
        let likedIds = (try? await service.getLikedCommentIds(reviewId: dbId)) ?? []

        // Build lookup of ReviewComment by ID
        var commentById: [UUID: ReviewComment] = [:]
        for c in dbComments {
            commentById[c.id] = ReviewComment(
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

        // Group children by parent
        var childrenOf: [UUID: [UUID]] = [:]
        var rootIds: [UUID] = []

        for c in dbComments {
            if let parentId = c.parentCommentId {
                childrenOf[parentId, default: []].append(c.id)
            } else {
                rootIds.append(c.id)
            }
        }

        // Recursively build tree
        func buildTree(id: UUID) -> ReviewComment? {
            guard var comment = commentById[id] else { return nil }
            if let childIds = childrenOf[id] {
                comment.replies = childIds.compactMap { buildTree(id: $0) }
            }
            return comment
        }

        var tree = rootIds.compactMap { buildTree(id: $0) }
        sortTopLevel(&tree)
        collapseAfterTop(&tree, visibleCount: 2)

        withAnimation(.easeOut(duration: 0.25)) {
            comments = tree
        }
    }

    /// Sort top-level comments by the user's chosen sort order.
    /// Replies are always ordered by engagement (handled at render time).
    private func sortTopLevel(_ list: inout [ReviewComment]) {
        let comparator: (ReviewComment, ReviewComment) -> Bool = {
            switch sortOrder {
            case .top: return { ($0.likes + $0.replies.count) > ($1.likes + $1.replies.count) }
            case .newest: return { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            case .oldest: return { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            }
        }()
        list.sort(by: comparator)
    }

    /// Collapse comments that have more than `visibleCount` replies.
    /// `isCollapsed = true` means show only the first N replies + "View X more".
    /// `isCollapsed = false` means show all replies.
    private func collapseAfterTop(_ list: inout [ReviewComment], visibleCount: Int) {
        for i in list.indices {
            list[i].isCollapsed = list[i].replies.count > visibleCount
            collapseAfterTop(&list[i].replies, visibleCount: visibleCount)
        }
    }

    private func sortComments() {
        sortTopLevel(&comments)
        collapseAfterTop(&comments, visibleCount: 2)
    }
}

// MARK: - Top Bar

private struct ReviewDetailTopBar: ViewModifier {
    let onBack: () -> Void
    var canDelete: Bool = false
    var onDelete: () -> Void = {}
    var onReport: () -> Void = {}
    var onBlock: () -> Void = {}

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
                    .background(Color.nook.reviewDetailBackground)
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
                    .foregroundStyle(Color.nook.reviewDetailTitle)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())

            Text("Review")
                .font(NookFont.labelBold)
                .foregroundStyle(Color.nook.reviewDetailTitle)

            Spacer()

            Menu {
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        sizedMenuLabel("Delete review", icon: "trash")
                    }
                } else {
                    Button(role: .destructive, action: onReport) {
                        sizedMenuLabel("Report", icon: "flag")
                    }

                    Button(action: onBlock) {
                        sizedMenuLabel("Block user", icon: "user-minus")
                    }
                }
            } label: {
                Image("dots-three-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.reviewDetailMeta)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Scroll Edge

private struct ReviewDetailSoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}


// MARK: - Comment Thread View (Continue this thread)

struct CommentThreadView: View {
    let root: ReviewComment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                renderTree(root, depth: 0)
            }
            .padding(.bottom, 40)
        }
        .background(Color.nook.reviewDetailBackground)
        .modifier(ReviewDetailTopBar(onBack: { dismiss() }))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .navigationDestination(for: ReviewComment.self) { comment in
            CommentThreadView(root: comment)
        }
    }

    private func renderTree(_ comment: ReviewComment, depth: Int) -> AnyView {
        if depth >= 3 && !comment.replies.isEmpty {
            return AnyView(
                VStack(spacing: 0) {
                    commentCell(comment, depth: depth)
                    NavigationLink(value: comment.replies[0]) {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(Color.nook.detailTabActive)
                                .frame(width: 2, height: 12)
                            Text("Continue this thread →")
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.detailTabActive)
                        }
                        .padding(.leading, 24 + CGFloat(min(depth + 1, 3)) * 24)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            )
        }

        return AnyView(
            VStack(spacing: 0) {
                commentCell(comment, depth: depth)
                ForEach(comment.replies) { reply in
                    renderTree(reply, depth: depth + 1)
                }
            }
        )
    }

    private func commentCell(_ comment: ReviewComment, depth: Int) -> some View {
        let indent = CGFloat(min(depth, 3)) * 24
        return HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.nook.reviewDetailDivider)
                    .frame(width: 2)
            }

            ReviewerAvatar(
                url: comment.authorAvatarURL,
                size: depth == 0 ? 36 : 28,
                iconSize: depth == 0 ? 14 : 11
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.reviewDetailTitle)

                    if let date = comment.createdAt {
                        Text(relativeTime(from: date))
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.reviewDetailMeta)
                    }
                }

                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.reviewDetailTitle)
                    .lineSpacing(4)

                if comment.likes > 0 {
                    HStack(spacing: 4) {
                        Image("heart-fill")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 14, height: 14)
                        Text("\(comment.likes)")
                            .font(NookFont.caption)
                    }
                    .foregroundStyle(Color.nook.reviewDetailMeta)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 24 + indent)
        .padding(.trailing, 24)
        .padding(.vertical, 12)
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReviewDetailView(
            review: ReviewItem(
                reviewerName: "Elena Vance",
                mediaTitle: "The Cloud Weaver",
                rating: 9.5,
                title: "An absolute masterpiece.",
                body: "An absolute masterclass in visual storytelling. The third act left me completely speechless. The world-building is unparalleled and the emotional payoff is entirely earned. Every frame feels deliberate, every scene builds on the last, and by the time the credits roll you're left wanting more.\n\nThe character development across 24 episodes is some of the most nuanced I've seen in anime. The protagonist's growth from an uncertain apprentice to a confident weaver mirrors the show's own evolution from a seemingly simple fantasy into something far more profound.\n\nMust watch for any fantasy fan.",
                likes: "1.2k",
                comments: "48"
            )
        )
    }
}
