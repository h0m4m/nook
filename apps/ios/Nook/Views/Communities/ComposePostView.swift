import PhotosUI
import SwiftUI

enum PollDuration: String, CaseIterable {
    case oneDay = "1 Day"
    case threeDays = "3 Days"
    case oneWeek = "1 Week"

    var seconds: TimeInterval {
        switch self {
        case .oneDay: 86_400
        case .threeDays: 259_200
        case .oneWeek: 604_800
        }
    }
}

struct ComposePostView: View {
    let clubName: String
    var clubId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var postBody = ""
    @State private var attachedImages: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isPosting = false
    @State private var showPoll = false
    @State private var pollOptions: [String] = ["", ""]
    @State private var pollDuration = PollDuration.oneDay
    @FocusState private var isBodyFocused: Bool
    @FocusState private var focusedPollOption: Int?

    private var canPost: Bool {
        let hasText = !postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !attachedImages.isEmpty
        let hasValidPoll = showPoll && pollOptions.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count >= 2
        return hasText || hasImages || hasValidPoll
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader
                editorContent
                bottomToolbar
            }
            .background(Color.nook.clubDetailBackground)
            .navigationBarHidden(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isBodyFocused = true
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $pickerSelection,
                maxSelectionCount: 10 - attachedImages.count,
                matching: .images
            )
            .onChange(of: pickerSelection) { _, newItems in
                guard !newItems.isEmpty else { return }
                appendImages(from: newItems)
                pickerSelection = []
            }
        }
    }

    private func appendImages(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if attachedImages.count < 10 {
                                attachedImages.append(uiImage)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Header

private extension ComposePostView {
    var sheetHeader: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.nook.clubDetailTitle)
                    .frame(width: 36, height: 36)
                    .background(Color.nook.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(clubName)
                .font(NookFont.labelBoldSmall)
                .foregroundStyle(Color.nook.clubDetailMeta)

            Spacer()

            Button {
                publishPost()
            } label: {
                Text("Post")
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(canPost ? Color.nook.primary : Color.nook.primary.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canPost || isPosting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Editor Content

private extension ComposePostView {
    var editorContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.nook.secondary)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.nook.mutedForeground)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(NookFont.labelSmall)
                            .foregroundStyle(Color.nook.clubDetailTitle)

                        Text("Posting to \(clubName)")
                            .font(NookFont.caption)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ZStack(alignment: .topLeading) {
                    if postBody.isEmpty {
                        Text("What's on your mind?")
                            .font(NookFont.label)
                            .foregroundStyle(Color.nook.clubDetailMeta)
                            .padding(.top, 20)
                            .padding(.leading, 20)
                            .onTapGesture {
                                isBodyFocused = true
                            }
                    }

                    TextEditor(text: $postBody)
                        .font(NookFont.label)
                        .foregroundStyle(Color.nook.clubDetailTitle)
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .focused($isBodyFocused)
                        .frame(minHeight: 160)
                        .padding(.horizontal, 15)
                        .padding(.top, 12)
                }

                if !attachedImages.isEmpty {
                    imageCarousel
                        .padding(.top, 8)
                }

                if showPoll {
                    pollEditor
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Image Carousel

private extension ComposePostView {
    var imageCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, uiImage in
                    imageCard(uiImage, at: index)
                }

                if attachedImages.count < 10 {
                    addMoreButton
                }
            }
            .padding(.horizontal, 20)
        }
    }

    func imageCard(_ uiImage: UIImage, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(
                    width: attachedImages.count == 1 ? UIScreen.main.bounds.width - 40 : 220,
                    height: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous))

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    _ = attachedImages.remove(at: index)
                }
            } label: {
                Image("x-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    var addMoreButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            VStack(spacing: 8) {
                Image("plus-bold")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.nook.clubDetailMeta)

                Text("Add")
                    .font(NookFont.captionBold)
                    .foregroundStyle(Color.nook.clubDetailMeta)
            }
            .frame(width: 80, height: 200)
            .background(
                RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                    .strokeBorder(Color.nook.detailTabBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Toolbar

private extension ComposePostView {
    var bottomToolbar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.nook.detailTabBorder)
                .frame(height: 1)

            HStack(spacing: 16) {
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image("image")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Color.nook.clubDetailTitle)

                        if !attachedImages.isEmpty {
                            Text("\(attachedImages.count)")
                                .font(NookFont.captionBold)
                                .foregroundStyle(Color.nook.clubDetailMeta)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPoll.toggle()
                        if showPoll {
                            pollOptions = ["", ""]
                        }
                    }
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18))
                        .foregroundStyle(showPoll ? Color.nook.primary : Color.nook.clubDetailTitle)
                }
                .buttonStyle(.plain)

                Spacer()

                if !postBody.isEmpty {
                    Text("\(postBody.count)")
                        .font(NookFont.caption)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.nook.clubDetailBackground)
    }
}

// MARK: - Poll Editor

private extension ComposePostView {
    var pollEditor: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Poll")
                    .font(NookFont.labelBold)
                    .foregroundStyle(Color.nook.clubDetailTitle)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPoll = false
                    }
                } label: {
                    Image("x-bold")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.nook.clubDetailMeta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Options
            VStack(spacing: 10) {
                ForEach(Array(pollOptions.enumerated()), id: \.offset) { index, _ in
                    pollOptionField(index: index)
                }

                if pollOptions.count < 6 {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            pollOptions.append("")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image("plus-bold")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)

                            Text("Add option")
                                .font(NookFont.labelMediumSmall)
                        }
                        .foregroundStyle(Color.nook.clubDetailMeta)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.nook.detailTabBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Duration picker
            HStack {
                Text("Duration")
                    .font(NookFont.labelMediumSmall)
                    .foregroundStyle(Color.nook.clubDetailTitle)

                Spacer()

                Menu {
                    ForEach(PollDuration.allCases, id: \.self) { duration in
                        Button {
                            pollDuration = duration
                        } label: {
                            HStack {
                                Text(duration.rawValue)
                                if pollDuration == duration {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(pollDuration.rawValue)
                            .font(NookFont.labelMediumSmall)
                            .foregroundStyle(Color.nook.clubDetailMeta)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.nook.clubDetailMeta)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                .fill(Color.nook.card)
                .overlay(
                    RoundedRectangle(cornerRadius: NookRadii.sm, style: .continuous)
                        .strokeBorder(Color.nook.clubDetailPostCardBorder, lineWidth: 1)
                )
        )
    }

    func pollOptionField(index: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .strokeBorder(Color.nook.detailTabBorder, lineWidth: 1.5)
                .frame(width: 18, height: 18)

            TextField(
                "Option \(index + 1)",
                text: $pollOptions[index]
            )
            .font(NookFont.labelMediumSmall)
            .foregroundStyle(Color.nook.clubDetailTitle)
            .focused($focusedPollOption, equals: index)

            if pollOptions.count > 2 {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        _ = pollOptions.remove(at: index)
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
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.nook.secondary)
        )
    }
}

// MARK: - Actions

private extension ComposePostView {
    func publishPost() {
        guard canPost else { return }
        isPosting = true

        let trimmedBody = postBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = attachedImages
        let pollDraft = buildPollDraft()

        Task {
            do {
                if let clubId {
                    let clubService = ClubService()
                    let imageDatas = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
                    try await clubService.createPost(
                        clubId: clubId,
                        body: trimmedBody,
                        imageDatas: imageDatas,
                        poll: pollDraft
                    )
                }

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                }
            }
        }
    }

    func buildPollDraft() -> ClubPollDraft? {
        guard showPoll else { return nil }
        let options = pollOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard options.count >= 2 else { return nil }
        return ClubPollDraft(options: options, closesAt: Date().addingTimeInterval(pollDuration.seconds))
    }
}

// MARK: - Preview

#Preview {
    ComposePostView(clubName: "Anime Corner")
}
