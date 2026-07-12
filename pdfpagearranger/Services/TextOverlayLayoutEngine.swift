import CoreGraphics
import UIKit

enum TextOverlayLayoutEngine {
    static let referencePageHeight: CGFloat = 792
    static let defaultWidthFraction: CGFloat = 0.45
    static let minWidthFraction: CGFloat = 0.12
    static let minHeightFraction: CGFloat = 0.04
    static let maxWidthFraction: CGFloat = 0.92
    static let maxHeightFraction: CGFloat = 0.85
    static let minFontSizePoints: CGFloat = 8
    static let maxFontSizePoints: CGFloat = 72

    static func clampedFontSize(_ points: CGFloat) -> CGFloat {
        min(max(points, minFontSizePoints), maxFontSizePoints)
    }

    static func font(
        sizePoints: CGFloat,
        bold: Bool,
        renderScale: CGFloat = 1
    ) -> UIFont {
        let size = max(sizePoints * renderScale, 1)
        if bold {
            return UIFont.boldSystemFont(ofSize: size)
        }
        return UIFont.systemFont(ofSize: size)
    }

    static func attributedString(
        for object: PageObject,
        renderScale: CGFloat = 1
    ) -> NSAttributedString {
        let text = TextOverlayFormattingEngine.displayText(
            object.textContent ?? "",
            listMode: object.textListMode ?? .plain
        )
        let fontSize = clampedFontSize(object.textFontSizePoints ?? TextOverlayDraft.defaultFontSizePoints)
        let font = Self.font(
            sizePoints: fontSize,
            bold: object.textBold ?? false,
            renderScale: renderScale
        )
        let color = (object.textColorRGBA ?? TextOverlayDraft.defaultColor).uiColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    static func measuredSize(
        text: String,
        fontSizePoints: CGFloat,
        bold: Bool,
        listMode: TextOverlayListMode,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat = defaultWidthFraction
    ) -> CGSize {
        let displayText = TextOverlayFormattingEngine.displayText(text, listMode: listMode)
        let font = font(sizePoints: clampedFontSize(fontSizePoints), bold: bold)
        let referenceWidth = widthFraction * referencePageHeight * pageAspectRatio
        let bounding = (displayText as NSString).boundingRect(
            with: CGSize(width: referenceWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).integral

        let widthFractionResult = min(
            max(widthFraction, minWidthFraction),
            maxWidthFraction
        )
        let heightFraction = min(
            max(bounding.height / referencePageHeight, minHeightFraction),
            maxHeightFraction
        )
        return CGSize(width: widthFractionResult, height: heightFraction)
    }

    static func renderScale(for layoutHeight: CGFloat, normalizedHeight: CGFloat) -> CGFloat {
        guard normalizedHeight > 0 else { return 1 }
        let referenceHeight = normalizedHeight * referencePageHeight
        return layoutHeight / max(referenceHeight, 1)
    }
}
