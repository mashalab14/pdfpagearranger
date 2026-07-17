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

    static let defaultFontSizePoints: CGFloat = 14
    static let defaultColor = SignatureInkRGBA(uiColor: .black)
    static let placeholderHint = "Text"
    static let maxListIndent = 4

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
        fontFamily: .system
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
        fontFamily: TextOverlayFontFamily = .system
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
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedText.isEmpty
    }

    mutating func clampListIndent() {
        listIndent = min(max(listIndent, 0), Self.maxListIndent)
    }
}
