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
        italic: Bool = false,
        family: TextOverlayFontFamily = .system,
        renderScale: CGFloat = 1
    ) -> UIFont {
        let size = max(sizePoints * renderScale, 1)
        let base: UIFont
        switch family {
        case .system:
            base = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        case .serif:
            let weight: UIFont.Weight = bold ? .bold : .regular
            if let descriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.serif)?
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]]) {
                base = UIFont(descriptor: descriptor, size: size)
            } else {
                base = UIFont(name: bold ? "Georgia-Bold" : "Georgia", size: size)
                    ?? (bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size))
            }
        case .monospaced:
            base = UIFont.monospacedSystemFont(
                ofSize: size,
                weight: bold ? .bold : .regular
            )
        }

        if italic, let italicDescriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: italicDescriptor, size: size)
        }
        return base
    }

    static func attributedString(
        for object: PageObject,
        renderScale: CGFloat = 1,
        placeholderWhenEmpty: Bool = false
    ) -> NSAttributedString {
        let listMode = object.textListMode ?? .plain
        let listIndent = object.textListIndent ?? 0
        let raw = object.textContent ?? ""
        let plain = TextOverlayFormattingEngine.plainText(from: raw, listMode: listMode)
        let defaults = TextOverlayRichTextEngine.StyleDefaults(from: object)
        let spans = TextOverlayRichTextEngine.normalizedSpans(
            object.textSpans,
            plainText: plain,
            defaults: defaults
        )
        return TextOverlayRichTextEngine.attributedString(
            spans: spans,
            defaults: defaults,
            alignment: object.textAlignment ?? .left,
            listMode: listMode,
            listIndent: listIndent,
            renderScale: renderScale,
            placeholderWhenEmpty: placeholderWhenEmpty
        )
    }

    static func attributedString(
        for draft: TextOverlayDraft,
        renderScale: CGFloat = 1,
        placeholderWhenEmpty: Bool = false,
        includeListMarkers: Bool = false
    ) -> NSAttributedString {
        var draft = draft
        draft.synchronizeSpansWithTextIfNeeded()
        let defaults = TextOverlayRichTextEngine.StyleDefaults(from: draft)
        return TextOverlayRichTextEngine.attributedString(
            spans: draft.spans,
            defaults: defaults,
            alignment: draft.alignment,
            listMode: includeListMarkers ? draft.listMode : .plain,
            listIndent: includeListMarkers ? draft.listIndent : 0,
            renderScale: renderScale,
            placeholderWhenEmpty: placeholderWhenEmpty
        )
    }

    static func attributedStringForDisplay(
        for draft: TextOverlayDraft,
        renderScale: CGFloat = 1,
        placeholderWhenEmpty: Bool = false
    ) -> NSAttributedString {
        attributedString(
            for: draft,
            renderScale: renderScale,
            placeholderWhenEmpty: placeholderWhenEmpty,
            includeListMarkers: true
        )
    }

    static func measuredSize(
        text: String,
        fontSizePoints: CGFloat,
        bold: Bool,
        italic: Bool = false,
        listMode: TextOverlayListMode,
        listIndent: Int = 0,
        fontFamily: TextOverlayFontFamily = .system,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat = defaultWidthFraction
    ) -> CGSize {
        let measureText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? TextOverlayDraft.placeholderHint
            : text
        let displayText = TextOverlayFormattingEngine.displayText(
            measureText,
            listMode: listMode,
            listIndent: listIndent
        )
        let font = font(
            sizePoints: clampedFontSize(fontSizePoints),
            bold: bold,
            italic: italic,
            family: fontFamily
        )
        let widthFractionResult = min(
            max(widthFraction, minWidthFraction),
            maxWidthFraction
        )
        let referenceWidth = widthFractionResult * referencePageHeight * pageAspectRatio
        let bounding = (displayText as NSString).boundingRect(
            with: CGSize(width: referenceWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).integral

        let heightFraction = min(
            max(bounding.height / referencePageHeight, minHeightFraction),
            maxHeightFraction
        )
        return CGSize(width: widthFractionResult, height: heightFraction)
    }

    static func measuredSize(
        for draft: TextOverlayDraft,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat
    ) -> CGSize {
        var draft = draft
        draft.synchronizeSpansWithTextIfNeeded()
        let attributed = attributedStringForDisplay(
            for: draft.isEmpty
                ? TextOverlayDraft(
                    text: TextOverlayDraft.placeholderHint,
                    fontSizePoints: draft.fontSizePoints,
                    colorRGBA: draft.colorRGBA,
                    isBold: draft.isBold,
                    isItalic: draft.isItalic,
                    isUnderline: draft.isUnderline,
                    isStrikethrough: draft.isStrikethrough,
                    alignment: draft.alignment,
                    listMode: draft.listMode,
                    listIndent: draft.listIndent,
                    fontFamily: draft.fontFamily,
                    opacity: draft.opacity,
                    spans: draft.spans
                )
                : draft,
            placeholderWhenEmpty: false
        )
        let widthFractionResult = min(
            max(widthFraction, minWidthFraction),
            maxWidthFraction
        )
        let referenceWidth = widthFractionResult * referencePageHeight * pageAspectRatio
        let bounding = attributed.boundingRect(
            with: CGSize(width: referenceWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
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

    private static func makeAttributedString(
        text: String,
        fontSizePoints: CGFloat,
        color: UIColor,
        bold: Bool,
        italic: Bool,
        underline: Bool,
        strikethrough: Bool,
        alignment: TextOverlayAlignment,
        fontFamily: TextOverlayFontFamily,
        renderScale: CGFloat,
        placeholderStyle: Bool
    ) -> NSAttributedString {
        let font = font(
            sizePoints: clampedFontSize(fontSizePoints),
            bold: bold,
            italic: italic,
            family: fontFamily,
            renderScale: renderScale
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = alignment.nsTextAlignment

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: placeholderStyle ? color.withAlphaComponent(0.35) : color,
            .paragraphStyle: paragraph
        ]
        if underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
}
