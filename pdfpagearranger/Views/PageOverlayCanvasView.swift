import SwiftUI

struct PageOverlayCanvasView: View {
    let pageImage: UIImage
    let objects: [PageObject]
    @Binding var selectedObjectID: UUID?
    let imageProvider: (UUID) -> UIImage?
    let onUpdate: (PageObject) -> Void
    let onDelete: (UUID) -> Void

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    private var pageZoomEnabled: Bool {
        selectedObjectID == nil
    }

    var body: some View {
        GeometryReader { geometry in
            let fitSize = aspectFitSize(imageSize: pageImage.size, in: geometry.size)

            pageStack(fitSize: fitSize)
                .frame(width: fitSize.width, height: fitSize.height)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(pageZoomEnabled ? magnificationGesture : nil)
                .simultaneousGesture(pageZoomEnabled ? panGesture : nil)
                .onTapGesture {
                    selectedObjectID = nil
                }
                .onTapGesture(count: 2) {
                    guard pageZoomEnabled else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        resetZoom()
                    }
                }
        }
    }

    @ViewBuilder
    private func pageStack(fitSize: CGSize) -> some View {
        ZStack {
            Image(uiImage: pageImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: fitSize.width, height: fitSize.height)

            ForEach(sortedObjects) { object in
                if object.type == .image,
                   let assetID = object.imageAssetID,
                   let overlayImage = imageProvider(assetID) {
                    ImageOverlayObjectView(
                        object: object,
                        image: overlayImage,
                        pageSize: fitSize,
                        canvasScale: scale,
                        isSelected: selectedObjectID == object.id,
                        onSelect: {
                            selectedObjectID = object.id
                            bringToFront(object)
                        },
                        onUpdate: onUpdate,
                        onDelete: {
                            onDelete(object.id)
                            if selectedObjectID == object.id {
                                selectedObjectID = nil
                            }
                        }
                    )
                }
            }
        }
    }

    private var sortedObjects: [PageObject] {
        objects.sorted { $0.zIndex < $1.zIndex }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(steadyScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                steadyScale = scale
                if scale <= minScale {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        resetZoom()
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                steadyOffset = offset
            }
    }

    private func resetZoom() {
        scale = minScale
        steadyScale = minScale
        offset = .zero
        steadyOffset = .zero
    }

    private func bringToFront(_ object: PageObject) {
        let maxZ = objects.map(\.zIndex).max() ?? 0
        guard object.zIndex < maxZ else { return }
        var updated = object
        updated.zIndex = maxZ + 1
        onUpdate(updated)
    }

    private func aspectFitSize(imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height
        let fitScale = min(widthScale, heightScale)

        return CGSize(
            width: imageSize.width * fitScale,
            height: imageSize.height * fitScale
        )
    }
}
