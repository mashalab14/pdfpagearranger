import Foundation
import UIKit

/// Contiguous rich-text run within a text overlay. Nil style fields inherit overlay defaults.
struct TextOverlayTextSpan: Codable, Equatable, Sendable {
    var text: String
    var fontSizePoints: CGFloat?
    var colorRGBA: SignatureInkRGBA?
    var isBold: Bool?
    var isItalic: Bool?
    var isUnderline: Bool?
    var isStrikethrough: Bool?
    var fontFamily: TextOverlayFontFamily?

    init(
        text: String,
        fontSizePoints: CGFloat? = nil,
        colorRGBA: SignatureInkRGBA? = nil,
        isBold: Bool? = nil,
        isItalic: Bool? = nil,
        isUnderline: Bool? = nil,
        isStrikethrough: Bool? = nil,
        fontFamily: TextOverlayFontFamily? = nil
    ) {
        self.text = text
        self.fontSizePoints = fontSizePoints
        self.colorRGBA = colorRGBA
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.fontFamily = fontFamily
    }

    var isEmpty: Bool { text.isEmpty }
}

enum TextOverlayRichTextEngine {
    struct StyleDefaults: Equatable {
        var fontSizePoints: CGFloat
        var colorRGBA: SignatureInkRGBA
        var isBold: Bool
        var isItalic: Bool
        var isUnderline: Bool
        var isStrikethrough: Bool
        var fontFamily: TextOverlayFontFamily

        init(from object: PageObject) {
            fontSizePoints = object.textFontSizePoints ?? TextOverlayDraft.defaultFontSizePoints
            colorRGBA = object.textColorRGBA ?? TextOverlayDraft.defaultColor
            isBold = object.textBold ?? false
            isItalic = object.textItalic ?? false
            isUnderline = object.textUnderline ?? false
            isStrikethrough = object.textStrikethrough ?? false
            fontFamily = object.textFontFamily ?? .system
        }

        init(
            fontSizePoints: CGFloat,
            colorRGBA: SignatureInkRGBA,
            isBold: Bool,
            isItalic: Bool,
            isUnderline: Bool,
            isStrikethrough: Bool,
            fontFamily: TextOverlayFontFamily
        ) {
            self.fontSizePoints = fontSizePoints
            self.colorRGBA = colorRGBA
            self.isBold = isBold
            self.isItalic = isItalic
            self.isUnderline = isUnderline
            self.isStrikethrough = isStrikethrough
            self.fontFamily = fontFamily
        }
    }

    static func plainText(from spans: [TextOverlayTextSpan]) -> String {
        spans.map(\.text).joined()
    }

    static func normalizedSpans(
        _ spans: [TextOverlayTextSpan]?,
        plainText body: String,
        defaults: StyleDefaults
    ) -> [TextOverlayTextSpan] {
        if let spans, !spans.isEmpty {
            let joined = plainText(from: spans)
            if joined == body {
                return mergeAdjacent(spans)
            }
        }
        guard !body.isEmpty else { return [] }
        return [
            TextOverlayTextSpan(
                text: body,
                fontSizePoints: defaults.fontSizePoints,
                colorRGBA: defaults.colorRGBA,
                isBold: defaults.isBold,
                isItalic: defaults.isItalic,
                isUnderline: defaults.isUnderline,
                isStrikethrough: defaults.isStrikethrough,
                fontFamily: defaults.fontFamily
            )
        ]
    }

    static func mergeAdjacent(_ spans: [TextOverlayTextSpan]) -> [TextOverlayTextSpan] {
        guard var current = spans.first else { return [] }
        var result: [TextOverlayTextSpan] = []
        for span in spans.dropFirst() {
            if stylesEqual(current, span) {
                current.text += span.text
            } else {
                if !current.text.isEmpty {
                    result.append(current)
                }
                current = span
            }
        }
        if !current.text.isEmpty {
            result.append(current)
        }
        return result
    }

    static func apply(
        range: NSRange,
        to spans: inout [TextOverlayTextSpan],
        defaults: StyleDefaults,
        update: (inout TextOverlayTextSpan) -> Void
    ) {
        guard range.length > 0, range.location >= 0 else { return }
        let plain = plainText(from: spans)
        let utf16Count = (plain as NSString).length
        guard range.location < utf16Count else { return }
        let end = min(range.location + range.length, utf16Count)

        var rebuilt: [TextOverlayTextSpan] = []
        var cursor = 0
        for span in spans {
            let spanUTF16 = span.text as NSString
            let spanLength = spanUTF16.length
            let spanStart = cursor
            let spanEnd = cursor + spanLength
            defer { cursor = spanEnd }

            if spanEnd <= range.location || spanStart >= end {
                rebuilt.append(span)
                continue
            }

            let localStart = max(0, range.location - spanStart)
            let localEnd = min(spanLength, end - spanStart)

            if localStart > 0 {
                rebuilt.append(
                    TextOverlayTextSpan(
                        text: spanUTF16.substring(with: NSRange(location: 0, length: localStart)),
                        fontSizePoints: span.fontSizePoints,
                        colorRGBA: span.colorRGBA,
                        isBold: span.isBold,
                        isItalic: span.isItalic,
                        isUnderline: span.isUnderline,
                        isStrikethrough: span.isStrikethrough,
                        fontFamily: span.fontFamily
                    )
                )
            }

            var middle = TextOverlayTextSpan(
                text: spanUTF16.substring(with: NSRange(location: localStart, length: localEnd - localStart)),
                fontSizePoints: span.fontSizePoints ?? defaults.fontSizePoints,
                colorRGBA: span.colorRGBA ?? defaults.colorRGBA,
                isBold: span.isBold ?? defaults.isBold,
                isItalic: span.isItalic ?? defaults.isItalic,
                isUnderline: span.isUnderline ?? defaults.isUnderline,
                isStrikethrough: span.isStrikethrough ?? defaults.isStrikethrough,
                fontFamily: span.fontFamily ?? defaults.fontFamily
            )
            update(&middle)
            rebuilt.append(middle)

            if localEnd < spanLength {
                rebuilt.append(
                    TextOverlayTextSpan(
                        text: spanUTF16.substring(with: NSRange(location: localEnd, length: spanLength - localEnd)),
                        fontSizePoints: span.fontSizePoints,
                        colorRGBA: span.colorRGBA,
                        isBold: span.isBold,
                        isItalic: span.isItalic,
                        isUnderline: span.isUnderline,
                        isStrikethrough: span.isStrikethrough,
                        fontFamily: span.fontFamily
                    )
                )
            }
        }
        spans = mergeAdjacent(rebuilt.filter { !$0.text.isEmpty })
    }

    static func spans(
        from attributed: NSAttributedString,
        defaults: StyleDefaults
    ) -> [TextOverlayTextSpan] {
        guard attributed.length > 0 else { return [] }
        var spans: [TextOverlayTextSpan] = []
        var index = 0
        while index < attributed.length {
            var effective = NSRange(location: 0, length: 0)
            let attrs = attributed.attributes(at: index, effectiveRange: &effective)
            let end = effective.location + effective.length
            let length = max(0, end - index)
            guard length > 0 else { break }
            let substring = (attributed.string as NSString).substring(
                with: NSRange(location: index, length: length)
            )
            let font = attrs[.font] as? UIFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let color = (attrs[.foregroundColor] as? UIColor).map(SignatureInkRGBA.init(uiColor:))
            spans.append(
                TextOverlayTextSpan(
                    text: substring,
                    fontSizePoints: font.map { TextOverlayLayoutEngine.clampedFontSize($0.pointSize) },
                    colorRGBA: color,
                    isBold: traits.contains(.traitBold) ? true : (font == nil ? nil : false),
                    isItalic: traits.contains(.traitItalic) ? true : (font == nil ? nil : false),
                    isUnderline: (attrs[.underlineStyle] as? Int).map { $0 != 0 },
                    isStrikethrough: (attrs[.strikethroughStyle] as? Int).map { $0 != 0 },
                    fontFamily: fontFamily(from: font)
                )
            )
            index = end
        }
        return mergeAdjacent(spans)
    }

    static func attributedString(
        spans: [TextOverlayTextSpan],
        defaults: StyleDefaults,
        alignment: TextOverlayAlignment,
        listMode: TextOverlayListMode,
        listIndent: Int,
        renderScale: CGFloat,
        placeholderWhenEmpty: Bool
    ) -> NSAttributedString {
        let plain = plainText(from: spans)
        if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if placeholderWhenEmpty {
                return TextOverlayLayoutEngine.attributedString(
                    for: TextOverlayDraft(
                        text: TextOverlayDraft.placeholderHint,
                        fontSizePoints: defaults.fontSizePoints,
                        colorRGBA: defaults.colorRGBA,
                        isBold: defaults.isBold,
                        isItalic: defaults.isItalic,
                        isUnderline: defaults.isUnderline,
                        isStrikethrough: defaults.isStrikethrough,
                        alignment: alignment,
                        listMode: .plain,
                        listIndent: 0,
                        fontFamily: defaults.fontFamily
                    ),
                    renderScale: renderScale,
                    placeholderWhenEmpty: true
                )
            }
            return NSAttributedString(string: "")
        }

        let body = NSMutableAttributedString()
        for span in spans {
            body.append(
                attributes(
                    for: span.text,
                    span: span,
                    defaults: defaults,
                    alignment: alignment,
                    renderScale: renderScale,
                    placeholderStyle: false
                )
            )
        }

        if listMode == .plain && listIndent == 0 {
            return body
        }

        return applyListMarkers(
            to: body,
            listMode: listMode,
            listIndent: listIndent,
            defaults: defaults,
            alignment: alignment,
            renderScale: renderScale
        )
    }

    private static func applyListMarkers(
        to body: NSAttributedString,
        listMode: TextOverlayListMode,
        listIndent: Int,
        defaults: StyleDefaults,
        alignment: TextOverlayAlignment,
        renderScale: CGFloat
    ) -> NSAttributedString {
        let lines = body.string.components(separatedBy: "\n")
        let result = NSMutableAttributedString()
        var utf16Cursor = 0
        var number = 1

        for (lineIndex, line) in lines.enumerated() {
            let lineUTF16Length = (line as NSString).length
            let lineRange = NSRange(location: utf16Cursor, length: lineUTF16Length)
            let lineAttr: NSAttributedString
            if lineUTF16Length == 0 {
                lineAttr = NSAttributedString(string: "")
            } else {
                lineAttr = body.attributedSubstring(from: lineRange)
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if lineIndex < lines.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
                utf16Cursor += lineUTF16Length + (lineIndex < lines.count - 1 ? 1 : 0)
                continue
            }

            let indent = String(repeating: "    ", count: min(max(listIndent, 0), TextOverlayDraft.maxListIndent))
            let marker: String
            switch listMode {
            case .plain:
                marker = ""
            case .bulleted:
                marker = "• "
            case .dashed:
                marker = "– "
            case .numbered:
                marker = "\(number). "
                number += 1
            }

            let prefix = indent + marker
            if !prefix.isEmpty {
                let firstAttrs = lineAttr.length > 0
                    ? lineAttr.attributes(at: 0, effectiveRange: nil)
                    : attributes(
                        for: " ",
                        span: TextOverlayTextSpan(text: " "),
                        defaults: defaults,
                        alignment: alignment,
                        renderScale: renderScale,
                        placeholderStyle: false
                    ).attributes(at: 0, effectiveRange: nil)
                result.append(NSAttributedString(string: prefix, attributes: firstAttrs))
            }
            result.append(lineAttr)
            if lineIndex < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
            utf16Cursor += lineUTF16Length + (lineIndex < lines.count - 1 ? 1 : 0)
        }
        return result
    }

    private static func attributes(
        for text: String,
        span: TextOverlayTextSpan,
        defaults: StyleDefaults,
        alignment: TextOverlayAlignment,
        renderScale: CGFloat,
        placeholderStyle: Bool
    ) -> NSAttributedString {
        let fontSize = TextOverlayLayoutEngine.clampedFontSize(span.fontSizePoints ?? defaults.fontSizePoints)
        let font = TextOverlayLayoutEngine.font(
            sizePoints: fontSize,
            bold: span.isBold ?? defaults.isBold,
            italic: span.isItalic ?? defaults.isItalic,
            family: span.fontFamily ?? defaults.fontFamily,
            renderScale: renderScale
        )
        let color = (span.colorRGBA ?? defaults.colorRGBA).uiColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = alignment.nsTextAlignment
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: placeholderStyle ? color.withAlphaComponent(0.35) : color,
            .paragraphStyle: paragraph
        ]
        if span.isUnderline ?? defaults.isUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if span.isStrikethrough ?? defaults.isStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return NSAttributedString(string: text, attributes: attrs)
    }

    private static func stylesEqual(_ lhs: TextOverlayTextSpan, _ rhs: TextOverlayTextSpan) -> Bool {
        lhs.fontSizePoints == rhs.fontSizePoints
            && lhs.colorRGBA == rhs.colorRGBA
            && lhs.isBold == rhs.isBold
            && lhs.isItalic == rhs.isItalic
            && lhs.isUnderline == rhs.isUnderline
            && lhs.isStrikethrough == rhs.isStrikethrough
            && lhs.fontFamily == rhs.fontFamily
    }

    private static func fontFamily(from font: UIFont?) -> TextOverlayFontFamily? {
        guard let font else { return nil }
        let name = font.fontName.lowercased()
        if name.contains("georgia") || name.contains("times") || name.contains("serif") {
            return .serif
        }
        if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) || name.contains("mono") {
            return .monospaced
        }
        return .system
    }
}
