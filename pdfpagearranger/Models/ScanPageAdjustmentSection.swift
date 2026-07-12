import Foundation

enum ScanPageAdjustmentSection: String, CaseIterable, Identifiable, Sendable {
    case crop = "Crop"
    case appearance = "Appearance"

    var id: String { rawValue }
}
