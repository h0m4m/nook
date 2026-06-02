import SwiftUI

enum CropShape {
    case roundedRect(cornerRadius: CGFloat)
    case circle
}

/// An item-driven crop request. Presenting the crop editor via
/// `.fullScreenCover(item:)` (instead of a bool + `if let`) avoids a race
/// where the cover comes up before the picked image is set, and gives the
/// cover stable identity so it lays out correctly.
struct CropRequest: Identifiable {
    let id = UUID()
    let image: UIImage
    let aspect: CGFloat
    var shape: CropShape = .roundedRect(cornerRadius: 24)
    let onCrop: (UIImage) -> Void
}

struct ImageCropView: View {
    let image: UIImage
    let cropAspect: CGFloat
    var cropShape: CropShape = .roundedRect(cornerRadius: 24)
    var onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero

    private var cropWidth: CGFloat { max(1, viewSize.width - 48) }
    private var cropHeight: CGFloat { cropWidth / cropAspect }

    private var baseFitSize: CGSize {
        let imgAspect = image.size.width / image.size.height
        let cropAsp = cropWidth / cropHeight
        if imgAspect > cropAsp {
            let h = cropHeight
            let w = h * imgAspect
            return CGSize(width: w, height: h)
        } else {
            let w = cropWidth
            let h = w / imgAspect
            return CGSize(width: w, height: h)
        }
    }

    private func clampedOffset(for currentScale: CGFloat) -> CGSize {
        let fit = baseFitSize
        let displayW = fit.width * currentScale
        let displayH = fit.height * currentScale
        let maxX = max(0, (displayW - cropWidth) / 2)
        let maxY = max(0, (displayH - cropHeight) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let fit = baseFitSize

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: fit.width, height: fit.height)
                        .scaleEffect(scale)
                        .offset(clampedOffset(for: scale))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = clampedOffset(for: scale)
                                    }
                                    lastOffset = clampedOffset(for: scale)
                                }
                        )
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value.magnification)
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        scale = max(1.0, scale)
                                        offset = clampedOffset(for: scale)
                                    }
                                    lastScale = scale
                                    lastOffset = clampedOffset(for: scale)
                                }
                        )

                    // Crop overlay
                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .reverseMask {
                            cropMaskShape
                                .frame(width: cropWidth, height: cropHeight)
                        }
                        .allowsHitTesting(false)

                    cropBorderShape
                        .frame(width: cropWidth, height: cropHeight)
                        .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .onAppear { viewSize = geo.size }
                .onChange(of: geo.size) { _, newSize in viewSize = newSize }
            }

            // Toolbar
            VStack {
                Spacer()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)

                    Spacer()

                    Button("Done") {
                        performCrop()
                    }
                    .font(NookFont.labelBoldSmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 40)
                    .background(.white.opacity(0.2), in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var cropMaskShape: some View {
        switch cropShape {
        case .roundedRect(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        case .circle:
            Circle()
        }
    }

    @ViewBuilder
    private var cropBorderShape: some View {
        switch cropShape {
        case .roundedRect(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
        case .circle:
            Circle()
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
        }
    }

    private func performCrop() {
        let fit = baseFitSize
        let clamped = clampedOffset(for: scale)

        guard fit.width > 0, fit.height > 0 else {
            onCrop(image)
            dismiss()
            return
        }

        let pppX = image.size.width / fit.width
        let pppY = image.size.height / fit.height

        let centerX = (image.size.width / 2) - (clamped.width / scale) * pppX
        let centerY = (image.size.height / 2) - (clamped.height / scale) * pppY

        let w = (cropWidth / scale) * pppX
        let h = (cropHeight / scale) * pppY

        var rect = CGRect(x: centerX - w / 2, y: centerY - h / 2, width: w, height: h)
        rect = rect.intersection(CGRect(origin: .zero, size: image.size))

        guard !rect.isEmpty, let cgImage = image.cgImage?.cropping(to: rect) else {
            onCrop(image)
            dismiss()
            return
        }

        onCrop(UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation))
        dismiss()
    }

    private func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
