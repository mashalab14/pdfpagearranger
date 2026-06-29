import CoreGraphics
import CoreText
import UIKit

enum WatermarkRenderer {
    struct Anchor {
        let point: CGPoint
    }

    static func displayAnchor(
        position: WatermarkPosition,
        renderSize: CGSize,
        marginFraction: CGFloat = 0.08
    ) -> Anchor {
        let normalized = position.normalizedDisplayPoint(marginFraction: marginFraction)
        return Anchor(
            point: CGPoint(
                x: normalized.x * renderSize.width,
                y: normalized.y * renderSize.height
            )
        )
    }

    static func pdfAnchor(
        position: WatermarkPosition,
        mediaBox: CGRect,
        pageRotation: Int,
        marginFraction: CGFloat = 0.08
    ) -> Anchor {
        let displaySize = OverlayGeometryEngine.displayRenderSize(for: pageRotation, mediaBox: mediaBox)
        let displayAnchor = displayAnchor(position: position, renderSize: displaySize, marginFraction: marginFraction)
        return Anchor(
            point: CGPoint(
                x: mediaBox.minX + displayAnchor.point.x,
                y: mediaBox.maxY - displayAnchor.point.y
            )
        )
    }

    static func drawInPDFContext(
        context: CGContext,
        mediaBox: CGRect,
        pageRotation: Int,
        settings: WatermarkSettings
    ) {
        let trimmed = settings.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fontSize = settings.scaledFontSize(forPageWidth: mediaBox.width)
        let anchor = pdfAnchor(
            position: settings.position,
            mediaBox: mediaBox,
            pageRotation: pageRotation
        )
        drawRotatedTextInPDFContext(
            trimmed,
            anchor: anchor,
            fontSize: fontSize,
            color: settings.color.uiColor,
            opacity: settings.opacity,
            rotationDegrees: settings.rotationDegrees,
            context: context
        )
    }

    static func compositeOnImage(
        baseImage: UIImage,
        pageRotation: Int,
        settings: WatermarkSettings,
        mediaBoxWidth: CGFloat
    ) -> UIImage {
        let trimmed = settings.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseImage }

        let renderSize = baseImage.size
        let fontSize = max(settings.scaledFontSize(forPageWidth: mediaBoxWidth > 0 ? mediaBoxWidth : renderSize.width), 8)
        let anchor = displayAnchor(position: settings.position, renderSize: renderSize)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = baseImage.scale
        return UIGraphicsImageRenderer(size: renderSize, format: format).image { rendererContext in
            baseImage.draw(at: .zero)
            drawRotatedTextInImageContext(
                trimmed,
                anchor: anchor,
                fontSize: fontSize,
                color: settings.color.uiColor,
                opacity: settings.opacity,
                rotationDegrees: settings.rotationDegrees,
                context: rendererContext.cgContext
            )
        }
    }

    private static func drawRotatedTextInPDFContext(
        _ text: String,
        anchor: Anchor,
        fontSize: CGFloat,
        color: UIColor,
        opacity: CGFloat,
        rotationDegrees: CGFloat,
        context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        context.saveGState()
        context.setAlpha(opacity)

        if rotationDegrees != 0 {
            context.translateBy(x: anchor.point.x, y: anchor.point.y)
            context.rotate(by: -rotationDegrees * .pi / 180)
        }

        let textRect: CGRect
        if rotationDegrees != 0 {
            textRect = CGRect(
                x: -textSize.width / 2,
                y: -textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
        } else {
            textRect = CGRect(
                x: anchor.point.x - textSize.width / 2,
                y: anchor.point.y - textSize.height / 2,
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
        anchor: Anchor,
        fontSize: CGFloat,
        color: UIColor,
        opacity: CGFloat,
        rotationDegrees: CGFloat,
        context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(opacity)
        context.translateBy(x: anchor.point.x, y: anchor.point.y)
        context.rotate(by: rotationDegrees * .pi / 180)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
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
