import CoreGraphics
import UIKit

/// Draws image overlays into a PDF graphics context using coordinates that match Page Mode.
enum OverlayPDFExporter {
    static func drawOverlays(
        _ objects: [PageObject],
        images: [UUID: UIImage],
        in pageBounds: CGRect,
        pageRotation: Int,
        context: CGContext
    ) {
        let displaySize = OverlayPageGeometry.displaySize(for: pageRotation, mediaBox: pageBounds)

        for object in objects.sorted(by: { $0.zIndex < $1.zIndex }) {
            guard object.type == .image,
                  let assetID = object.imageAssetID,
                  let image = images[assetID],
                  let cgImage = image.cgImage else {
                continue
            }

            let geometry = object.displayGeometry(pageRotation: pageRotation)
            drawOverlay(
                cgImage,
                geometry: geometry,
                opacity: object.opacity,
                displaySize: displaySize,
                pageBounds: pageBounds,
                in: context
            )
        }
    }

    private static func drawOverlay(
        _ image: CGImage,
        geometry: OverlayPageGeometry.Transformed,
        opacity: CGFloat,
        displaySize: CGSize,
        pageBounds: CGRect,
        in context: CGContext
    ) {
        let width = geometry.size.width * displaySize.width
        let height = geometry.size.height * displaySize.height
        let centerX = pageBounds.minX + geometry.position.x * displaySize.width
        // Page Mode uses a top-left origin; PDF uses bottom-left.
        let centerY = pageBounds.maxY - geometry.position.y * displaySize.height

        context.saveGState()
        context.setAlpha(opacity)

        if geometry.rotation != 0 {
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: -geometry.rotation * .pi / 180)
            drawImage(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), context: context)
        } else {
            drawImage(
                image,
                in: CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height),
                context: context
            )
        }

        context.restoreGState()
    }

    /// CGImage rows are top-first; flip when drawing into a PDF context.
    private static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
}
