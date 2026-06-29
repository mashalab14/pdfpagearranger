import PencilKit
import UIKit

enum SignatureInkThickness: String, CaseIterable, Identifiable, Codable, Equatable {
    case thin
    case medium
    case thick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thin:
            return "Thin"
        case .medium:
            return "Medium"
        case .thick:
            return "Thick"
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .thin:
            return 1.5
        case .medium:
            return 2.5
        case .thick:
            return 4.0
        }
    }

    var accessibilityIdentifier: String {
        "signatureThickness_\(rawValue)"
    }

    static let defaultThickness: SignatureInkThickness = .medium

    func inkingTool(color: SignatureInkColor) -> PKInkingTool {
        PKInkingTool(.pen, color: color.uiColor, width: strokeWidth)
    }
}

enum SignatureCaptureSettings {
    static let storageKey = "signatureInkThickness"

    static func storedThickness(in defaults: UserDefaults = .standard) -> SignatureInkThickness {
        guard let rawValue = defaults.string(forKey: storageKey),
              let thickness = SignatureInkThickness(rawValue: rawValue) else {
            return .defaultThickness
        }
        return thickness
    }

    static func setStoredThickness(_ thickness: SignatureInkThickness, in defaults: UserDefaults = .standard) {
        defaults.set(thickness.rawValue, forKey: storageKey)
    }

    static func clearStoredThickness(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
