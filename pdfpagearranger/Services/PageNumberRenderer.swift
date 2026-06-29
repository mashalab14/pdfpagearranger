import CoreGraphics
import CoreText
import UIKit

enum PageNumberRenderer {
    enum TextAlignment {
        case left
        case center
        case right
    }

    struct Anchor {
        let point: CGPoint
        let alignment: TextAlignment
    }

    static func formattedText(
        settings: PageNumberSettings,
        displayNumber: Int,
        totalPages: Int
    ) -> String {
        settings.format.formattedText(number: displayNumber, totalPages: totalPages)
    }

    static func pdfAnchor(
        position: PageNumberPosition,
        mediaBox: CGRect,
        pageRotation: Int,
        marginFraction: CGFloat = 0.04
    ) -> Anchor {
        let normalized = position.normalizedDisplayPoint(marginFraction: marginFraction)
        let displaySize = OverlayGeometryEngine.displayRenderSize(for: pageRotation, mediaBox: mediaBox)
        let displayPoint = CGPoint(
            x: normalized.x * displaySize.width,
            y: normalized.y * displaySize.height
        )
        let pdfPoint = CGPoint(
            x: mediaBox.minX + displayPoint.x,
            y: mediaBox.maxY - displayPoint.y
        )
        let alignment: TextAlignment
        switch position {
        case .bottomLeft, .topLeft:
            alignment = .left
        case .bottomCenter, .topCenter:
            alignment = .center
        case .bottomRight, .topRight:
            alignment = .right
        }
        return Anchor(point: pdfPoint, alignment: alignment)
    }

    static func displayAnchor(
        position: PageNumberPosition,
        renderSize: CGSize,
        marginFraction: CGFloat = 0.04
    ) -> Anchor {
        let normalized = position.normalizedDisplayPoint(marginFraction: marginFraction)
        let point = CGPoint(
            x: normalized.x * renderSize.width,
            y: normalized.y * renderSize.height
        )
        let alignment: TextAlignment
        switch position {
        case .bottomLeft, .topLeft:
            alignment = .left
        case .bottomCenter, .topCenter:
            alignment = .center
        case .bottomRight, .topRight:
            alignment = .right
        }
        return Anchor(point: point, alignment: alignment)
    }

    static func drawInPDFContext(
        context: CGContext,
        mediaBox: CGRect,
        pageRotation: Int,
        settings: PageNumberSettings,
        displayNumber: Int,
        totalPages: Int
    ) {
        let text = formattedText(
            settings: settings,
            displayNumber: displayNumber,
            totalPages: totalPages
        )
        let anchor = pdfAnchor(
            position: settings.position,
            mediaBox: mediaBox,
            pageRotation: pageRotation
        )
        drawTextInPDFContext(
            text,
            anchor: anchor,
            fontSize: settings.fontSize,
            opacity: settings.opacity,
            mediaBox: mediaBox,
            context: context
        )
    }

    static func compositeOnImage(
        baseImage: UIImage,
        pageRotation: Int,
        settings: PageNumberSettings,
        displayNumber: Int,
        totalPages: Int
    ) -> UIImage {
        let text = formattedText(
            settings: settings,
            displayNumber: displayNumber,
            totalPages: totalPages
        )
        let renderSize = baseImage.size
        let scale = renderSize.width / 612.0
        let fontSize = max(settings.fontSize * scale, 8)
        let anchor = displayAnchor(position: settings.position, renderSize: renderSize)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = baseImage.scale
        return UIGraphicsImageRenderer(size: renderSize, format: format).image { rendererContext in
            baseImage.draw(at: .zero)
            drawTextInImageContext(
                text,
                anchor: anchor,
                fontSize: fontSize,
                opacity: settings.opacity,
                context: rendererContext.cgContext
            )
        }
    }

    private static func drawTextInPDFContext(
        _ text: String,
        anchor: Anchor,
        fontSize: CGFloat,
        opacity: CGFloat,
        mediaBox: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(opacity)

        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let textRect = pdfTextRect(for: anchor, textSize: textSize, mediaBox: mediaBox)
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

    private static func pdfTextRect(
        for anchor: Anchor,
        textSize: CGSize,
        mediaBox: CGRect
    ) -> CGRect {
        let x: CGFloat
        switch anchor.alignment {
        case .left:
            x = anchor.point.x
        case .center:
            x = anchor.point.x - textSize.width / 2
        case .right:
            x = anchor.point.x - textSize.width
        }

        let y = anchor.point.y - textSize.height / 2
        let maxX = mediaBox.maxX - textSize.width
        return CGRect(
            x: max(mediaBox.minX, min(x, maxX)),
            y: max(mediaBox.minY, y),
            width: textSize.width,
            height: textSize.height
        )
    }

    private static func drawTextInImageContext(
        _ text: String,
        anchor: Anchor,
        fontSize: CGFloat,
        opacity: CGFloat,
        context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(opacity)

        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let rect = textRect(for: anchor, textSize: textSize, in: .zero)
        (text as NSString).draw(in: rect, withAttributes: attributes)

        context.restoreGState()
    }

    private static func textRect(
        for anchor: Anchor,
        textSize: CGSize,
        in boundsSize: CGSize
    ) -> CGRect {
        let x: CGFloat
        switch anchor.alignment {
        case .left:
            x = anchor.point.x
        case .center:
            x = anchor.point.x - textSize.width / 2
        case .right:
            x = anchor.point.x - textSize.width
        }

        let y = anchor.point.y - textSize.height / 2
        let maxWidth = boundsSize.width > 0 ? boundsSize.width : .greatestFiniteMagnitude
        return CGRect(
            x: max(0, min(x, maxWidth - textSize.width)),
            y: y,
            width: textSize.width,
            height: textSize.height
        )
    }
}
