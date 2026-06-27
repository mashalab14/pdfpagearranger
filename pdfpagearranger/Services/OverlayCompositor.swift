import UIKit

/// Composites image overlays onto a rendered PDF page image using normalized coordinates.
enum OverlayCompositor {
    static func composite(
        baseImage: UIImage,
        objects: [PageObject],
        images: [UUID: UIImage]
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

                drawOverlay(
                    overlayImage,
                    object: object,
                    pageSize: pageSize,
                    in: context.cgContext
                )
            }
        }
    }

    private static func drawOverlay(
        _ image: UIImage,
        object: PageObject,
        pageSize: CGSize,
        in context: CGContext
    ) {
        let width = object.size.width * pageSize.width
        let height = object.size.height * pageSize.height
        let centerX = object.position.x * pageSize.width
        let centerY = object.position.y * pageSize.height

        context.saveGState()
        context.setAlpha(object.opacity)

        if object.rotation != 0 {
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: object.rotation * .pi / 180)
            context.translateBy(x: -width / 2, y: -height / 2)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            image.draw(in: CGRect(
                x: centerX - width / 2,
                y: centerY - height / 2,
                width: width,
                height: height
            ))
        }

        context.restoreGState()
    }
}
