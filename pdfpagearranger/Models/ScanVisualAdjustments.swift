import CoreGraphics
import Foundation

enum ScanVisualMode: String, Codable, CaseIterable, Equatable, Sendable {
    case original
    case enhanced
    case grayscale
    case blackAndWhite

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .enhanced: return "Enhanced"
        case .grayscale: return "Grayscale"
        case .blackAndWhite: return "Black & White"
        }
    }

    var supportsSaturationControl: Bool {
        switch self {
        case .original, .enhanced: return true
        case .grayscale, .blackAndWhite: return false
        }
    }

    var supportsThresholdControl: Bool {
        self == .blackAndWhite
    }
}

/// Reusable visual-adjustment settings shared across pages.
/// Crop and perspective geometry live in `ScanPageGeometry`, not here.
struct ScanVisualAdjustments: Equatable, Codable, Hashable, Sendable {
    /// Normalized offset from neutral in range `minimumAdjustmentValue...maximumAdjustmentValue`.
    static let minimumAdjustmentValue: CGFloat = -1
    static let maximumAdjustmentValue: CGFloat = 1
    static let defaultBlackAndWhiteThreshold: CGFloat = 0.5
    static let minimumBlackAndWhiteThreshold: CGFloat = 0.2
    static let maximumBlackAndWhiteThreshold: CGFloat = 0.8

    var mode: ScanVisualMode = .original
    var brightness: CGFloat = 0
    var contrast: CGFloat = 0
    /// Optional saturation offset for Original and Enhanced modes only.
    var saturation: CGFloat?
    /// Threshold pivot for Black and White mode.
    var blackAndWhiteThreshold: CGFloat?

    static let neutral = ScanVisualAdjustments()

    var requiresProcessing: Bool {
        let normalized = normalizedForProcessing()
        if normalized.mode != .original { return true }
        if normalized.brightness != 0 || normalized.contrast != 0 { return true }
        if normalized.saturation != nil { return true }
        return false
    }

    func copied() -> ScanVisualAdjustments {
        self
    }

    func resetToDefaults() -> ScanVisualAdjustments {
        .neutral
    }

    func normalizedForProcessing() -> ScanVisualAdjustments {
        var copy = self
        copy.brightness = Self.clampedAdjustment(copy.brightness)
        copy.contrast = Self.clampedAdjustment(copy.contrast)
        if let saturation = copy.saturation {
            copy.saturation = Self.clampedSaturation(saturation)
        }
        if copy.mode == .blackAndWhite {
            copy.blackAndWhiteThreshold = copy.resolvedBlackAndWhiteThreshold
        } else {
            copy.blackAndWhiteThreshold = nil
        }
        if !copy.mode.supportsSaturationControl {
            copy.saturation = nil
        }
        return copy
    }

    var resolvedBlackAndWhiteThreshold: CGFloat {
        let value = blackAndWhiteThreshold ?? Self.defaultBlackAndWhiteThreshold
        return min(max(value, Self.minimumBlackAndWhiteThreshold), Self.maximumBlackAndWhiteThreshold)
    }

    func resolvedSaturation(for mode: ScanVisualMode) -> CGFloat? {
        guard mode.supportsSaturationControl else { return nil }
        guard let saturation else { return nil }
        let clamped = Self.clampedSaturation(saturation)
        return clamped == 0 ? nil : clamped
    }

    static func clampedAdjustment(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumAdjustmentValue), maximumAdjustmentValue)
    }

    static func clampedSaturation(_ value: CGFloat) -> CGFloat {
        min(max(value, -0.5), 0.5)
    }
}

extension ScanVisualAdjustments {
    /// Maps normalized UI slider values to Core Image brightness input (-1…1 UI → ±0.35 CI).
    var coreImageBrightness: CGFloat {
        brightness * 0.35
    }

    /// Maps normalized UI slider values to Core Image contrast offset (-1…1 UI → ±0.35 added to 1.0).
    var coreImageContrast: CGFloat {
        contrast * 0.35
    }

    /// Maps normalized UI saturation slider to Core Image saturation offset.
    var coreImageSaturation: CGFloat? {
        guard mode.supportsSaturationControl else { return nil }
        guard let saturation else { return nil }
        let clamped = Self.clampedSaturation(saturation)
        return clamped == 0 ? nil : clamped * 0.5
    }
}
