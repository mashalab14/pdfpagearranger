import SwiftUI

struct PageOverlayCanvasView: View {
    let pageImage: UIImage
    let objects: [PageObject]
    @Binding var selectedObjectID: UUID?
    let imageProvider: (UUID) -> UIImage?
    let onUpdate: (PageObject) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let fitSize = aspectFitSize(imageSize: pageImage.size, in: geometry.size)

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
            .frame(width: fitSize.width, height: fitSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedObjectID = nil
            }
        }
    }

    private var sortedObjects: [PageObject] {
        objects.sorted { $0.zIndex < $1.zIndex }
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
        let scale = min(widthScale, heightScale)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
}
