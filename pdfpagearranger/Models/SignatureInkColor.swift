import SwiftUI
import UIKit

enum SignatureInkColor: String, CaseIterable, Identifiable {
    case black
    case darkGray
    case blue
    case red
    case green
    case purple

    var id: String { rawValue }

    var uiColor: UIColor {
        switch self {
        case .black:
            return UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .darkGray:
            return UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1)
        case .blue:
            return UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        case .red:
            return UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        case .green:
            return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        case .purple:
            return UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)
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
