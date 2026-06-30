import Foundation

enum PlacedSignatureStrokeWidth {
    static let minimumPoints = 2
    static let maximumPoints = 30
    static let defaultPoints = 3

    static func clamped(_ value: Int) -> Int {
        min(max(value, minimumPoints), maximumPoints)
    }

    static func label(for points: Int) -> String {
        "\(clamped(points)) pt"
    }

    static func points(for thickness: SignatureInkThickness) -> Int {
        switch thickness {
        case .thin:
            return 2
        case .medium:
            return 3
        case .thick:
            return 6
        }
    }

    static func libraryThickness(for points: Int) -> SignatureInkThickness {
        switch clamped(points) {
        case ..<3:
            return .thin
        case 3...5:
            return .medium
        default:
            return .thick
        }
    }

    static func decreased(from points: Int) -> Int? {
        let next = clamped(points) - 1
        guard next >= minimumPoints else { return nil }
        return next
    }

    static func increased(from points: Int) -> Int? {
        let next = clamped(points) + 1
        guard next <= maximumPoints else { return nil }
        return next
    }
}
