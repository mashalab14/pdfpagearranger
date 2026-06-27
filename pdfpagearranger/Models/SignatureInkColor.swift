import SwiftUI
import UIKit

enum SignatureInkColor: String, CaseIterable, Identifiable {
    case black
    case blue
    case darkGray

    var id: String { rawValue }

    var uiColor: UIColor {
        switch self {
        case .black:
            return UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .blue:
            return UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        case .darkGray:
            return UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1)
        }
    }

    var displayColor: Color {
        Color(uiColor)
    }

    var accessibilityIdentifier: String {
        "signatureColor_\(rawValue)"
    }

    static let defaultInk: SignatureInkColor = .black
}
