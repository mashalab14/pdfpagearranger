import CoreGraphics
import UIKit

/// Draws image overlays into a PDF graphics context using shared geometry mapping.
enum OverlayPDFExporter {
    static func drawOverlays(
        _ objects: [PageObject],
        images: [UUID: UIImage],
        in pageBounds: CGRect,
        pageRotation: Int,
        context: CGContext
    ) {
        for object in objects.sorted(by: { $0.zIndex < $1.zIndex }) {
            guard object.usesRasterImageAsset,
                  let assetID = object.imageAssetID,
                  let image = images[assetID],
                  let cgImage = image.cgImage else {
                continue
            }

            let layout = OverlayGeometryEngine.pdfLayout(
                for: object,
                pageRotation: pageRotation,
                mediaBox: pageBounds
            )
            OverlayGeometryEngine.drawPDFImage(
                cgImage,
                layout: layout,
                opacity: object.opacity,
                in: context
            )
        }
    }
}
