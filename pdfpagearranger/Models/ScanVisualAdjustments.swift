import CoreGraphics
import Foundation

enum ScanVisualMode: String, Codable, CaseIterable, Equatable, Sendable {
    case original
    case enhanced
    case grayscale
    case blackAndWhite
}

/// Reusable visual-adjustment settings shared across pages.
/// Crop and perspective geometry live in `ScanPageGeometry`, not here.
struct ScanVisualAdjustments: Equatable, Codable, Hashable, Sendable {
    var mode: ScanVisualMode = .original
    /// Normalized offset from neutral; future pipeline maps to image adjustments.
    var brightness: CGFloat = 0
    var contrast: CGFloat = 0
    /// Optional when the processing pipeline needs explicit saturation control.
    var saturation: CGFloat?
    /// Optional threshold for black-and-white mode.
    var blackAndWhiteThreshold: CGFloat?

    static let neutral = ScanVisualAdjustments()

    func copied() -> ScanVisualAdjustments {
        self
    }
}
