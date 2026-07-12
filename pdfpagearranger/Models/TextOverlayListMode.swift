import Foundation
import UIKit

enum TextOverlayListMode: String, Codable, Equatable, Sendable {
    case plain
    case bulleted
    case numbered
}

struct TextOverlayDraft: Equatable, Sendable {
    var text: String
    var fontSizePoints: CGFloat
    var colorRGBA: SignatureInkRGBA
    var isBold: Bool
    var listMode: TextOverlayListMode

    static let defaultFontSizePoints: CGFloat = 14
    static let defaultColor = SignatureInkRGBA(uiColor: .black)

    static let `default` = TextOverlayDraft(
        text: "",
        fontSizePoints: defaultFontSizePoints,
        colorRGBA: defaultColor,
        isBold: false,
        listMode: .plain
    )

    init(
        text: String,
        fontSizePoints: CGFloat = Self.defaultFontSizePoints,
        colorRGBA: SignatureInkRGBA = Self.defaultColor,
        isBold: Bool = false,
        listMode: TextOverlayListMode = .plain
    ) {
        self.text = text
        self.fontSizePoints = fontSizePoints
        self.colorRGBA = colorRGBA
        self.isBold = isBold
        self.listMode = listMode
    }

    init(from object: PageObject) {
        text = object.textContent ?? ""
        fontSizePoints = object.textFontSizePoints ?? Self.defaultFontSizePoints
        colorRGBA = object.textColorRGBA ?? Self.defaultColor
        isBold = object.textBold ?? false
        listMode = object.textListMode ?? .plain
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        trimmedText.isEmpty
    }
}
