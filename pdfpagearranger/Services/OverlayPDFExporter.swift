import CoreGraphics
import UIKit

enum OverlayPDFExporter {
    static func drawOverlays(
        _ objects: [PageObject],
        images: [UUID: UIImage],
        in pageBounds: CGRect,
        pageRotation: Int,
        context: CGContext
    ) {
        for object in objects.sorted(by: { $0.zIndex < $1.zIndex }) {
            if object.isTextOverlay {
                let layout = OverlayGeometryEngine.pdfLayout(
                    for: object,
                    pageRotation: pageRotation,
                    mediaBox: pageBounds
                )
                TextOverlayRenderer.drawTextOverlay(
                    object,
                    layout: layout,
                    opacity: object.opacity,
                    in: context,
                    coordinateSpace: .pdfMediaBox
                )
                continue
            }

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
