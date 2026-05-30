import SwiftUI

// MARK: - Comment Model

struct NookComment: Identifiable {
    let id = UUID()
    let authorName: String
    let timeAgo: String
    let body: String
    var likes: Int
    var isLiked: Bool
    var replies: [NookComment]

    init(
        authorName: String,
        timeAgo: String,
        body: String,
        likes: Int = 0,
        isLiked: Bool = false,
        replies: [NookComment] = []
    ) {
        self.authorName = authorName
        self.timeAgo = timeAgo
        self.body = body
        self.likes = likes
        self.isLiked = isLiked
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
    @State private var comments: [NookComment]
    @State private var replyingTo: String?
    @State private var commentsVisible = false
    @State private var expandedNoteID: UUID?
    @State private var isLoadingDetail = false
    @FocusState private var isCommentFocused: Bool

    init(nook: NookItem) {
        self._nook = State(initialValue: nook)
        self._likeCount = State(initialValue: nook.likes)
        self._comments = State(initialValue: Self.mockComments)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        contentSection
                    }
                }
                .ignoresSafeArea(edges: .top)

                if commentsVisible {
                    replyBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            navigationBar
        }
        .background(Color.nook.detailBackground.ignoresSafeArea())
        .background(
            VStack(spacing: 0) {
                (nook.placeholderColor ?? Color.nook.foreground)
                    .frame(height: 400)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(InteractivePopGesture())
        .task {
            guard let dbId = nook.dbId else { return }
            isLoadingDetail = true
            let nookService = NookService()
            if let detail = try? await nookService.getNook(nookId: dbId) {
                nook = NookItem(from: detail)
                likeCount = 0
            }
            isLoadingDetail = false
        }
    }

    // MARK: - Hero

    private let heroHeight: CGFloat = 394

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Cover image
            Group {
                if let url = nook.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            (nook.placeholderColor ?? Color.nook.foreground)
                        }
                    }
                } else if let color = nook.placeholderColor {
                    color
                } else if !nook.imageName.isEmpty {
                    Image(nook.imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.nook.foreground
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .clipped()

            // Gradient: fades to page bg at bottom, dark at top for nav buttons
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0xFDFCF9), location: 0),
                    .init(color: Color(hex: 0xFDFCF9).opacity(0.2), location: 0.5),
                    .init(color: .black.opacity(0.3), location: 1.0),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: heroHeight)

            // Content overlay at bottom
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(nook.title)
                    .font(.custom("Outfit-Bold", size: 28))
                    .lineSpacing(2)
                    .foregroundStyle(Color(hex: 0x1C1917))

                // Author
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: 0xFDFCF9), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(nook.curatorName)
                            .font(NookFont.captionSemiBold)
                            .foregroundStyle(Color(hex: 0x1C1917))

                        Text("Published Oct 12, 2023")
                            .font(.custom("PlusJakartaSans-Regular", size: 10))
                            .foregroundStyle(Color(hex: 0x78716C))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: heroHeight)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 8) {
            heroButton(icon: "caret-left-bold", action: { dismiss() })

            Spacer()

            heroButton(icon: "heart", action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }
                generator.impactOccurred()
            })

            heroButton(icon: "export", action: {})
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func heroButton(icon: String, action: @escaping () -> Void) -> some View {
        let isHeartFilled = icon == "heart" && isLiked
        let resolvedIcon = isHeartFilled ? "heart-fill" : icon

        if #available(iOS 26, *) {
            Button(action: action) {
                Image(resolvedIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isHeartFilled ? Color.nook.clubDetailLikeActive : .primary)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Button(action: action) {
                Image(resolvedIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isHeartFilled ? Color.nook.clubDetailLikeActive : .white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
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
                    Image("heart")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text("\(likeCount)")
                        .font(NookFont.captionSemiBold)
                }
                .foregroundStyle(Color.nook.detailMeta)

                HStack(spacing: 5) {
                    Image("chat-circle")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text("\(nook.comments)")
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

                Text("\(comments.count)")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailMeta)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .onGeometryChange(for: Bool.self) { geo in
                let frame = geo.frame(in: .global)
                return frame.maxY > 0 && frame.minY < UIScreen.main.bounds.height
            } action: { visible in
                withAnimation(.easeOut(duration: 0.2)) {
                    commentsVisible = visible
                }
            }

            // Comments
            commentsSection
        }
        .background(Color.nook.detailBackground)
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

    private var commentsSection: some View {
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

    private func commentRow(
        _ comment: NookComment,
        depth: Int,
        index: Int,
        replyIndex: Int? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.nook.detailTabBorder)
                    .frame(width: 2)
                    .padding(.leading, 36)
            }

            Circle()
                .fill(Color.nook.secondary)
                .frame(
                    width: depth == 0 ? 36 : 28,
                    height: depth == 0 ? 36 : 28
                )
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: depth == 0 ? 14 : 11))
                        .foregroundStyle(Color.nook.mutedForeground)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(NookFont.captionBold)
                        .foregroundStyle(Color.nook.detailTitle)

                    Text(comment.timeAgo)
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)
                }

                Text(comment.body)
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.detailTitle)
                    .lineSpacing(4)

                HStack(spacing: 16) {
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
                        .foregroundStyle(
                            comment.isLiked
                                ? Color.nook.clubDetailLikeActive
                                : Color.nook.detailMeta
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            replyingTo = comment.authorName
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            if let replyTo = replyingTo {
                HStack {
                    Text("Replying to \(replyTo)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.detailMeta)

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
                    replyingTo != nil ? "Reply..." : "Add a comment...",
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

    private func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let newComment = NookComment(
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
        }

        commentText = ""
        isCommentFocused = false
    }
}

// MARK: - Mock Comments

extension NookDetailView {
    static let mockComments: [NookComment] = [
        NookComment(
            authorName: "Alex",
            timeAgo: "2h",
            body: "This is such a perfect collection. The autumn vibes are immaculate.",
            likes: 12,
            replies: [
                NookComment(
                    authorName: "Sarah",
                    timeAgo: "1h",
                    body: "Thank you! Took me a while to curate this one 🍂",
                    likes: 5
                ),
            ]
        ),
        NookComment(
            authorName: "Jordan",
            timeAgo: "5h",
            body: "Foundation's Edge is such an underrated pick. Most people go for the first book but the later ones have so much more depth.",
            likes: 8
        ),
        NookComment(
            authorName: "Riley",
            timeAgo: "1d",
            body: "Adding Frieren to this was genius. It fits the vibe perfectly.",
            likes: 15,
            replies: [
                NookComment(
                    authorName: "Alex",
                    timeAgo: "12h",
                    body: "Right? The pacing of that show is exactly the feeling this nook captures.",
                    likes: 3
                ),
            ]
        ),
    ]
}
