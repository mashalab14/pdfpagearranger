import UIKit

/// Composites image overlays onto a rendered PDF page image using shared geometry mapping.
enum OverlayCompositor {
    static func composite(
        baseImage: UIImage,
        objects: [PageObject],
        images: [UUID: UIImage],
        pageRotation: Int = 0
    ) -> UIImage {
        guard !objects.isEmpty else { return baseImage }

        let pageSize = baseImage.size
        let renderer = UIGraphicsImageRenderer(size: pageSize)

        return renderer.image { context in
            baseImage.draw(in: CGRect(origin: .zero, size: pageSize))

            for object in objects.sorted(by: { $0.zIndex < $1.zIndex }) {
                guard object.type == .image,
                      let assetID = object.imageAssetID,
                      let overlayImage = images[assetID] else {
                    continue
                }

                let layout = OverlayGeometryEngine.thumbnailLayout(
                    for: object,
                    pageRotation: pageRotation,
                    renderSize: pageSize
                )
                OverlayGeometryEngine.drawUIImage(
                    overlayImage,
                    layout: layout,
                    opacity: object.opacity,
                    in: context.cgContext
                )
            }
        }
    }
}
