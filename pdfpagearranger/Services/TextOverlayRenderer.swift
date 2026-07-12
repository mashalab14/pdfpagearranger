import CoreGraphics
import UIKit

enum TextOverlayRenderer {
    static func drawTextOverlay(
        _ object: PageObject,
        layout: OverlayGeometryEngine.Layout,
        opacity: CGFloat,
        in context: CGContext,
        coordinateSpace: OverlayGeometryEngine.CoordinateSpace
    ) {
        guard object.type == .text else { return }

        let renderScale = TextOverlayLayoutEngine.renderScale(
            for: layout.size.height,
            normalizedHeight: object.size.height
        )
        let attributed = TextOverlayLayoutEngine.attributedString(
            for: object,
            renderScale: renderScale
        )
        guard attributed.length > 0 else { return }

        context.saveGState()
        context.setAlpha(opacity)

        switch coordinateSpace {
        case .topLeftOrigin:
            drawTopLeftOrigin(attributed: attributed, layout: layout, in: context)
        case .pdfMediaBox:
            drawPDFMediaBox(attributed: attributed, layout: layout, in: context)
        }

        context.restoreGState()
    }

    private static func drawTopLeftOrigin(
        attributed: NSAttributedString,
        layout: OverlayGeometryEngine.Layout,
        in context: CGContext
    ) {
        if layout.rotationDegrees != 0 {
            context.translateBy(x: layout.center.x, y: layout.center.y)
            context.rotate(by: layout.rotationDegrees * .pi / 180)
            let rect = CGRect(
                x: -layout.size.width / 2,
                y: -layout.size.height / 2,
                width: layout.size.width,
                height: layout.size.height
            )
            drawAttributedString(attributed, in: rect, context: context)
        } else {
            drawAttributedString(attributed, in: layout.topLeftBounds, context: context)
        }
    }

    private static func drawPDFMediaBox(
        attributed: NSAttributedString,
        layout: OverlayGeometryEngine.Layout,
        in context: CGContext
    ) {
        if layout.rotationDegrees != 0 {
            context.translateBy(x: layout.center.x, y: layout.center.y)
            context.rotate(by: -layout.rotationDegrees * .pi / 180)
            let rect = CGRect(
                x: -layout.size.width / 2,
                y: -layout.size.height / 2,
                width: layout.size.width,
                height: layout.size.height
            )
            flipDrawAttributedString(attributed, in: rect, context: context)
        } else {
            flipDrawAttributedString(attributed, in: layout.topLeftBounds, context: context)
        }
    }

    private static func drawAttributedString(
        _ attributed: NSAttributedString,
        in rect: CGRect,
        context: CGContext
    ) {
        UIGraphicsPushContext(context)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        UIGraphicsPopContext()
    }

    private static func flipDrawAttributedString(
        _ attributed: NSAttributedString,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        let flipped = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
        drawAttributedString(attributed, in: flipped, context: context)
        context.restoreGState()
    }
}
