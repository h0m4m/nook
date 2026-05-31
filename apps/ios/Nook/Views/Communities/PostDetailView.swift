import SwiftUI

// MARK: - Comment Model

struct PostComment: Identifiable {
    let id = UUID()
    let authorName: String
    let timeAgo: String
    let body: String
    var likes: Int
    var isLiked: Bool
    var replies: [PostComment]

    init(
        authorName: String,
        timeAgo: String,
        body: String,
        likes: Int = 0,
        isLiked: Bool = false,
        replies: [PostComment] = []
    ) {
        self.authorName = authorName
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
    @State private var isLiked = false
    @State private var likeCount: String
    @State private var commentText = ""
    @State private var comments: [PostComment]
    @FocusState private var isCommentFocused: Bool
    @State private var replyingTo: String?
    @State private var sortOrder: CommentSort = .top

    init(post: ClubPost) {
        self.post = post
        self._likeCount = State(initialValue: post.likes)
        self._comments = State(initialValue: Self.mockComments)
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
            PostDetailTopBar(onBack: { dismiss() })
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
        guard let dbId = post.dbId else { return }
        let clubService = ClubService()

        // Load comments
        if let rows = try? await clubService.getComments(postId: dbId) {
            let loaded = rows.map { row in
                PostComment(
                    authorName: row.userProfile?.fullName ?? row.userProfile?.username ?? "Member",
                    timeAgo: "",
                    body: row.body
                )
            }
            if !loaded.isEmpty {
                comments = loaded
            }
        }
    }
}

// MARK: - Post Content (full post displayed at top)

private extension PostDetailView {
    var postContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.nook.secondary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.nook.mutedForeground)
                    )

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

            // Post image
            if post.imageName != nil || post.placeholderColor != nil {
                postImage
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

    var postImage: some View {
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
                }
                generator.impactOccurred()

                if let dbId = post.dbId {
                    Task {
                        let service = ClubService()
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

                    Text(likeCount)
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

                Text(post.comments)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }

            Spacer()

            // Share
            Button {
                // TODO: Share sheet
            } label: {
                Image("share-network")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }
            .buttonStyle(.plain)
        }
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
                Text("\(comments.count) Comments")
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
            ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                VStack(spacing: 0) {
                    commentRow(comment, depth: 0, index: index)

                    ForEach(Array(comment.replies.enumerated()), id: \.element.id) { replyIndex, reply in
                        commentRow(reply, depth: 1, index: index, replyIndex: replyIndex)
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

            Circle()
                .fill(Color.nook.secondary)
                .frame(width: depth == 0 ? 36 : 28, height: depth == 0 ? 36 : 28)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: depth == 0 ? 14 : 11))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

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
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if let ri = replyIndex {
                                comments[index].replies[ri].isLiked.toggle()
                                comments[index].replies[ri].likes += comments[index].replies[ri].isLiked ? 1 : -1
                            } else {
                                comments[index].isLiked.toggle()
                                comments[index].likes += comments[index].isLiked ? 1 : -1
                            }
                        }
                        generator.impactOccurred()
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
                            replyingTo = comment.authorName
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
}

// MARK: - Reply Bar

private extension PostDetailView {
    var replyBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            if let replyTo = replyingTo {
                HStack {
                    Text("Replying to \(replyTo)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            replyingTo = nil
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
                    replyingTo != nil ? "Reply..." : "Add a comment...",
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

        let newComment = PostComment(
            authorName: "You",
            timeAgo: "now",
            body: text
        )

        withAnimation(.easeOut(duration: 0.25)) {
            if replyingTo != nil {
                if !comments.isEmpty {
                    comments[0].replies.append(newComment)
                }
                replyingTo = nil
            } else {
                comments.insert(newComment, at: 0)
            }
            commentText = ""
        }

        isCommentFocused = false

        // Persist to DB
        if let dbId = post.dbId {
            Task {
                let service = ClubService()
                try? await service.addComment(postId: dbId, body: text)
            }
        }
    }

    private func sortComments() {
        switch sortOrder {
        case .top:
            comments.sort { $0.likes > $1.likes }
        case .newest:
            comments.sort { lhs, rhs in
                sortValue(lhs.timeAgo) < sortValue(rhs.timeAgo)
            }
        case .oldest:
            comments.sort { lhs, rhs in
                sortValue(lhs.timeAgo) > sortValue(rhs.timeAgo)
            }
        }
    }

    private func sortValue(_ timeAgo: String) -> Int {
        let parts = timeAgo.split(separator: " ")
        guard let num = Int(parts.first ?? "0") else {
            if timeAgo == "now" { return 0 }
            return 999
        }
        let unit = String(parts.last ?? "m")
        switch unit {
        case "m": return num
        case "h": return num * 60
        case "d": return num * 1440
        default: return num
        }
    }
}

// MARK: - Top Bar

private struct PostDetailTopBar: ViewModifier {
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
                Button(role: .destructive) {
                    // TODO: Report post
                } label: {
                    Label {
                        Text("Report")
                            .font(.subheadline)
                    } icon: {
                        Image("flag")
                            .renderingMode(.template)
                    }
                }

                Button {
                    // TODO: Copy link
                } label: {
                    Label {
                        Text("Copy link")
                            .font(.subheadline)
                    } icon: {
                        Image("link")
                            .renderingMode(.template)
                    }
                }

                Button {
                    // TODO: Block user
                } label: {
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

// MARK: - Mock Comments

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
        PostComment(
            authorName: "Liam Brooks",
            timeAgo: "58m",
            body: "Am I the only one who thinks the pacing in the last two episodes was a bit rushed? Still loved it but felt like they crammed a lot in.",
            likes: 12,
            replies: [
                PostComment(
                    authorName: "Ava Kim",
                    timeAgo: "40m",
                    body: "Agreed. They could have easily split episode 12 into two. But the emotional beats still landed for me.",
                    likes: 5
                ),
            ]
        ),
        PostComment(
            authorName: "Nadia Petrova",
            timeAgo: "45m",
            body: "Just here to say the soundtrack in the cloud weaving scenes is on another level. Anyone know the composer?",
            likes: 23
        ),
        PostComment(
            authorName: "Jin Park",
            timeAgo: "30m",
            body: "Yuki Kajiura. She's done some legendary work. Check out her discography if you haven't already.",
            likes: 31
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
                body: "Just finished episode 12 of The Cloud Weaver and I'm completely blown away. The art direction in the sky kingdom scenes is some of the best I've seen in years. Does anyone know if the manga covers past this arc?",
                boldRanges: ["The Cloud Weaver"],
                placeholderColor: Color(hex: 0x87CEEB).opacity(0.6),
                likes: "1.2k",
                comments: "84"
            )
        )
    }
}
