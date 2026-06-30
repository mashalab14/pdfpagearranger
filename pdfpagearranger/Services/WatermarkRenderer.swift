import CoreGraphics
import CoreText
import UIKit

enum WatermarkRenderer {
    static func drawInPDFContext(
        context: CGContext,
        mediaBox: CGRect,
        pageRotation: Int,
        settings: WatermarkSettings
    ) {
        let trimmed = settings.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let displaySize = OverlayGeometryEngine.displayRenderSize(
            for: pageRotation,
            mediaBox: mediaBox
        )
        guard let layout = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            text: trimmed,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: displaySize,
            coordinateSpace: .pdfMediaBox
        ) else {
            return
        }

        drawRotatedTextInPDFContext(
            trimmed,
            layout: layout,
            color: settings.color.uiColor,
            opacity: settings.opacity,
            context: context
        )
    }

    static func compositeOnImage(
        pageImage: UIImage,
        pageRotation: Int,
        settings: WatermarkSettings,
        mediaBox: CGRect
    ) -> UIImage {
        let trimmed = settings.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pageImage }

        let renderSize = pageImage.size
        guard let layout = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            text: trimmed,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: renderSize,
            coordinateSpace: .topLeftOrigin
        ) else {
            return pageImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = pageImage.scale
        return UIGraphicsImageRenderer(size: renderSize, format: format).image { rendererContext in
            switch settings.layer {
            case .aboveContent:
                pageImage.draw(at: .zero)
                drawRotatedTextInImageContext(
                    trimmed,
                    layout: layout,
                    color: settings.color.uiColor,
                    opacity: settings.opacity,
                    context: rendererContext.cgContext
                )
            case .behindContent:
                UIColor.white.setFill()
                rendererContext.fill(CGRect(origin: .zero, size: renderSize))
                drawRotatedTextInImageContext(
                    trimmed,
                    layout: layout,
                    color: settings.color.uiColor,
                    opacity: settings.opacity,
                    context: rendererContext.cgContext
                )
                pageImage.draw(at: .zero)
            }
        }
    }

    private static func drawRotatedTextInPDFContext(
        _ text: String,
        layout: WatermarkGeometryEngine.ConcreteLayout,
        color: UIColor,
        opacity: CGFloat,
        context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: layout.fontSize),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        context.saveGState()
        context.setAlpha(opacity)

        if layout.rotationDegrees != 0 {
            context.translateBy(x: layout.center.x, y: layout.center.y)
            context.rotate(by: -layout.rotationDegrees * .pi / 180)
        }

        let textRect: CGRect
        if layout.rotationDegrees != 0 {
            textRect = CGRect(
                x: -textSize.width / 2,
                y: -textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
        } else {
            textRect = CGRect(
                x: layout.center.x - textSize.width / 2,
                y: layout.center.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
        }

        let path = CGPath(rect: textRect, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private static func drawRotatedTextInImageContext(
        _ text: String,
        layout: WatermarkGeometryEngine.ConcreteLayout,
        color: UIColor,
        opacity: CGFloat,
        context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(opacity)
        context.translateBy(x: layout.center.x, y: layout.center.y)
        context.rotate(by: layout.rotationDegrees * .pi / 180)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: layout.fontSize),
            .foregroundColor: color
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: -textSize.width / 2,
            y: -textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: rect, withAttributes: attributes)
        context.restoreGState()
    }
}
