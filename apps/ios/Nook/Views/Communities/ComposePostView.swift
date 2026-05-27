import PhotosUI
import SwiftUI

struct ComposePostView: View {
    let clubName: String
    @Environment(\.dismiss) private var dismiss
    @State private var postBody = ""
    @State private var attachedImages: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isPosting = false
    @FocusState private var isBodyFocused: Bool

    private var canPost: Bool {
        !postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty
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

// MARK: - Actions

private extension ComposePostView {
    func publishPost() {
        guard canPost else { return }
        isPosting = true

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            generator.notificationOccurred(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ComposePostView(clubName: "Anime Corner")
}
