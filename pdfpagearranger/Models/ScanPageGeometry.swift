import CoreGraphics
import Foundation

/// Normalized point in original-image space (0…1, top-left origin).
struct ScanNormalizedPoint: Equatable, Codable, Hashable, Sendable {
    var x: CGFloat
    var y: CGFloat
}

/// Page-specific crop and perspective geometry, independent of visual adjustments.
struct ScanPageGeometry: Equatable, Codable, Hashable, Sendable {
    /// Document-boundary corners detected by future edge detection.
    var detectedCorners: [ScanNormalizedPoint]?
    /// User-refined corners for crop and perspective correction.
    var userAdjustedCorners: [ScanNormalizedPoint]?
    /// Normalized crop rectangle in original-image space.
    var cropRect: CGRect?
    var perspectiveCorrectionEnabled: Bool = false
    /// Clockwise page rotation in degrees (0, 90, 180, 270).
    var rotation: Int = 0

    static let `default` = ScanPageGeometry()

    var effectiveCorners: [ScanNormalizedPoint]? {
        if let userAdjustedCorners, !userAdjustedCorners.isEmpty {
            return userAdjustedCorners
        }
        return detectedCorners
    }

    func rotated() -> ScanPageGeometry {
        var copy = self
        copy.rotation = (rotation + 90) % 360
        return copy
    }
}
