import Foundation
import SwiftUI
import UIKit

enum TextOverlayListMode: String, Codable, Equatable, Sendable, CaseIterable {
    case plain
    case bulleted
    case numbered
    case dashed
}

enum TextOverlayAlignment: String, Codable, Equatable, Sendable, CaseIterable {
    case left
    case center
    case right

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    var swiftUIAlignment: Alignment {
        switch self {
        case .left: return .topLeading
        case .center: return .top
        case .right: return .topTrailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

enum TextOverlayFontFamily: String, Codable, Equatable, Sendable, CaseIterable {
    case system
    case serif
    case monospaced

    var displayName: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .monospaced: return "Mono"
        }
    }
}

struct TextOverlayDraft: Equatable, Sendable {
    var text: String
    var fontSizePoints: CGFloat
    var colorRGBA: SignatureInkRGBA
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var isStrikethrough: Bool
    var alignment: TextOverlayAlignment
    var listMode: TextOverlayListMode
    var listIndent: Int
    var fontFamily: TextOverlayFontFamily
    /// Overlay opacity (not color alpha), 0.05…1.
    var opacity: CGFloat
    /// Rich-text runs covering `text`. Empty means fall back to whole-overlay defaults.
    var spans: [TextOverlayTextSpan]
    /// Current UTF-16 selection in the inline editor (used for range formatting).
    var selectedUTF16Location: Int
    var selectedUTF16Length: Int

    static let defaultFontSizePoints: CGFloat = 14
    static let defaultColor = SignatureInkRGBA(uiColor: .black)
    static let placeholderHint = "Text"
    static let maxListIndent = 4
    static let minOpacity: CGFloat = 0.05
    static let maxOpacity: CGFloat = 1

    static let `default` = TextOverlayDraft(
        text: "",
        fontSizePoints: defaultFontSizePoints,
        colorRGBA: defaultColor,
        isBold: false,
        isItalic: false,
        isUnderline: false,
        isStrikethrough: false,
        alignment: .left,
        listMode: .plain,
        listIndent: 0,
        fontFamily: .system,
        opacity: 1,
        spans: [],
        selectedUTF16Location: 0,
        selectedUTF16Length: 0
    )

    init(
        text: String,
        fontSizePoints: CGFloat = Self.defaultFontSizePoints,
        colorRGBA: SignatureInkRGBA = Self.defaultColor,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        alignment: TextOverlayAlignment = .left,
        listMode: TextOverlayListMode = .plain,
        listIndent: Int = 0,
        fontFamily: TextOverlayFontFamily = .system,
        opacity: CGFloat = 1,
        spans: [TextOverlayTextSpan] = [],
        selectedUTF16Location: Int = 0,
        selectedUTF16Length: Int = 0
    ) {
        self.text = text
        self.fontSizePoints = fontSizePoints
        self.colorRGBA = colorRGBA
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.alignment = alignment
        self.listMode = listMode
        self.listIndent = min(max(listIndent, 0), Self.maxListIndent)
        self.fontFamily = fontFamily
        self.opacity = Self.clampedOpacity(opacity)
        self.spans = spans
        self.selectedUTF16Location = selectedUTF16Location
        self.selectedUTF16Length = selectedUTF16Length
        synchronizeSpansWithTextIfNeeded()
    }

    init(from object: PageObject) {
        let mode = object.textListMode ?? .plain
        text = TextOverlayFormattingEngine.plainText(
            from: object.textContent ?? "",
            listMode: mode
        )
        fontSizePoints = object.textFontSizePoints ?? Self.defaultFontSizePoints
        colorRGBA = object.textColorRGBA ?? Self.defaultColor
        isBold = object.textBold ?? false
        isItalic = object.textItalic ?? false
        isUnderline = object.textUnderline ?? false
        isStrikethrough = object.textStrikethrough ?? false
        alignment = object.textAlignment ?? .left
        listMode = mode
        listIndent = object.textListIndent ?? 0
        fontFamily = object.textFontFamily ?? .system
        opacity = Self.clampedOpacity(object.opacity)
        selectedUTF16Location = 0
        selectedUTF16Length = 0
        let defaults = TextOverlayRichTextEngine.StyleDefaults(from: object)
        spans = TextOverlayRichTextEngine.normalizedSpans(
            object.textSpans,
            plainText: text,
            defaults: defaults
        )
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedText.isEmpty
    }

    var selectedRange: NSRange {
        NSRange(location: selectedUTF16Location, length: selectedUTF16Length)
    }

    var hasTextSelection: Bool {
        selectedUTF16Length > 0
    }

    static func clampedOpacity(_ value: CGFloat) -> CGFloat {
        min(max(value, minOpacity), maxOpacity)
    }

    mutating func clampListIndent() {
        listIndent = min(max(listIndent, 0), Self.maxListIndent)
    }

    mutating func synchronizeSpansWithTextIfNeeded() {
        let defaults = TextOverlayRichTextEngine.StyleDefaults(from: self)
        spans = TextOverlayRichTextEngine.normalizedSpans(spans, plainText: text, defaults: defaults)
    }

    /// Applies a style mutation to the selected range, or updates typing defaults when nothing is selected.
    mutating func applyFormatting(updateDefaults: (inout TextOverlayDraft) -> Void, updateSpan: (inout TextOverlayTextSpan) -> Void) {
        synchronizeSpansWithTextIfNeeded()
        if hasTextSelection {
            let defaults = TextOverlayRichTextEngine.StyleDefaults(from: self)
            TextOverlayRichTextEngine.apply(
                range: selectedRange,
                to: &spans,
                defaults: defaults,
                update: updateSpan
            )
            text = TextOverlayRichTextEngine.plainText(from: spans)
        } else {
            updateDefaults(&self)
            if !text.isEmpty, spans.count <= 1 {
                synchronizeSpansWithTextIfNeeded()
                if var only = spans.first {
                    updateSpan(&only)
                    spans = [only]
                }
            }
        }
    }
}

extension TextOverlayRichTextEngine.StyleDefaults {
    init(from draft: TextOverlayDraft) {
        self.init(
            fontSizePoints: draft.fontSizePoints,
            colorRGBA: draft.colorRGBA,
            isBold: draft.isBold,
            isItalic: draft.isItalic,
            isUnderline: draft.isUnderline,
            isStrikethrough: draft.isStrikethrough,
            fontFamily: draft.fontFamily
        )
    }
}
