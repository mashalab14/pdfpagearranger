import UIKit

/// Composites image overlays onto a rendered PDF page image using normalized coordinates.
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

                let geometry = object.displayGeometry(pageRotation: pageRotation)
                drawOverlay(
                    overlayImage,
                    geometry: geometry,
                    opacity: object.opacity,
                    pageSize: pageSize,
                    in: context.cgContext
                )
            }
        }
    }

    private static func drawOverlay(
        _ image: UIImage,
        geometry: OverlayPageGeometry.Transformed,
        opacity: CGFloat,
        pageSize: CGSize,
        in context: CGContext
    ) {
        let width = geometry.size.width * pageSize.width
        let height = geometry.size.height * pageSize.height
        let centerX = geometry.position.x * pageSize.width
        let centerY = geometry.position.y * pageSize.height

        context.saveGState()
        context.setAlpha(opacity)

        if geometry.rotation != 0 {
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: geometry.rotation * .pi / 180)
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
