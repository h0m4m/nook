import SwiftUI

// MARK: - Review Comment Model

struct ReviewComment: Identifiable {
    let id = UUID()
    let authorName: String
    let timeAgo: String
    let body: String
    var likes: Int
    var isLiked: Bool
    var replies: [ReviewComment]

    init(
        authorName: String,
        timeAgo: String,
        body: String,
        likes: Int = 0,
        isLiked: Bool = false,
        replies: [ReviewComment] = []
    ) {
        self.authorName = authorName
        self.timeAgo = timeAgo
        self.body = body
        self.likes = likes
        self.isLiked = isLiked
        self.replies = replies
    }
}

// MARK: - Review Detail View

struct ReviewDetailView: View {
    let review: ReviewItem
    @Environment(\.dismiss) private var dismiss
    @State private var isLiked = false
    @State private var commentText = ""
    @State private var comments: [ReviewComment]
    @FocusState private var isCommentFocused: Bool
    @State private var replyingTo: String?
    @State private var sortOrder: CommentSort = .top

    init(review: ReviewItem) {
        self.review = review
        self._comments = State(initialValue: Self.mockComments)
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
            .modifier(ReviewDetailSoftScrollEdge())

            replyBar
        }
        .background(Color.nook.reviewDetailBackground)
        .modifier(
            ReviewDetailTopBar(onBack: { dismiss() })
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .onTapGesture {
            isCommentFocused = false
        }
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
            mediaContextCard
                .padding(.top, 16)
                .padding(.horizontal, 24)

            // Review title
            Text(review.title)
                .font(NookFont.labelLarge)
                .foregroundStyle(Color.nook.reviewDetailTitle)
                .padding(.top, 20)
                .padding(.horizontal, 24)

            // Review body
            Text(review.body)
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
            // Avatar
            Circle()
                .fill(Color.nook.secondary)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(review.reviewerName)
                    .font(NookFont.labelSmall)
                    .foregroundStyle(Color.nook.reviewDetailTitle)

                Text("reviewed \(review.mediaTitle)")
                    .font(NookFont.caption)
                    .foregroundStyle(Color.nook.reviewDetailMeta)
            }

            Spacer()

            // Rating badge
            HStack(spacing: 3) {
                Image("star-fill")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.nook.detailRatingText)

                Text(String(format: "%.1f", review.rating))
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

    var mediaContextCard: some View {
        HStack(spacing: 12) {
            // Media poster placeholder
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.nook.secondary)
                .frame(width: 48, height: 68)
                .overlay(
                    Image("reel")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.nook.mutedForeground)
                )

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
                .fill(Color.nook.reviewDetailMediaCard)
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                }
                generator.impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Image(isLiked ? "heart-fill" : "heart")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(isLiked ? Color.nook.reviewDetailLikeActive : Color.nook.reviewDetailMeta)
                        .scaleEffect(isLiked ? 1.15 : 1.0)

                    Text(review.likes)
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

                Text(review.comments)
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(Color.nook.reviewDetailMeta)
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
                    .foregroundStyle(Color.nook.reviewDetailMeta)
            }
            .buttonStyle(.plain)
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

    func commentRow(_ comment: ReviewComment, depth: Int, index: Int, replyIndex: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.nook.reviewDetailDivider)
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
                        .foregroundStyle(Color.nook.reviewDetailTitle)

                    Text(comment.timeAgo)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.reviewDetailMeta)
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
                        .foregroundStyle(comment.isLiked ? Color.nook.reviewDetailLikeActive : Color.nook.reviewDetailMeta)
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
                            .foregroundStyle(Color.nook.reviewDetailMeta)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
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

            if let replyTo = replyingTo {
                HStack {
                    Text("Replying to \(replyTo)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.reviewDetailMeta)

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
                            .foregroundStyle(Color.nook.reviewDetailMeta)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
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

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let newComment = ReviewComment(
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

private struct ReviewDetailTopBar: ViewModifier {
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
                Button(role: .destructive) {
                    // TODO: Report review
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

// MARK: - Mock Comments

extension ReviewDetailView {
    static let mockComments: [ReviewComment] = [
        ReviewComment(
            authorName: "Kai Tanaka",
            timeAgo: "3h",
            body: "Couldn't agree more about the third act. The way they tied everything together with the cloud weaving motif was brilliant. Easily my anime of the year.",
            likes: 34,
            replies: [
                ReviewComment(
                    authorName: "Nadia Petrova",
                    timeAgo: "2h",
                    body: "Same here. I went in with low expectations and was completely blown away.",
                    likes: 12
                ),
                ReviewComment(
                    authorName: "Jin Park",
                    timeAgo: "1h",
                    body: "The foreshadowing from episode 3 that pays off in the finale is just *chef's kiss*",
                    likes: 8
                ),
            ]
        ),
        ReviewComment(
            authorName: "Sophia Chen",
            timeAgo: "2h",
            body: "Great review! I'd love to hear your thoughts on the soundtrack too. I think it really elevated the emotional beats in ways that don't get enough credit.",
            likes: 28
        ),
        ReviewComment(
            authorName: "Liam Brooks",
            timeAgo: "1h",
            body: "Interesting take on the world-building. I thought the magic system could have been explained a bit more clearly, but the visual storytelling made up for it.",
            likes: 15,
            replies: [
                ReviewComment(
                    authorName: "Ava Kim",
                    timeAgo: "45m",
                    body: "I actually prefer when they show rather than tell with magic systems. Felt more immersive that way.",
                    likes: 9
                ),
            ]
        ),
        ReviewComment(
            authorName: "Marcus Rivera",
            timeAgo: "45m",
            body: "9.5 is a bold rating but honestly it's deserved. This show set a new bar for the genre.",
            likes: 41
        ),
    ]
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
