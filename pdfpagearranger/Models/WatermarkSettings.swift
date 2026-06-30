import CoreGraphics
import Foundation
import UIKit

enum WatermarkPosition: String, CaseIterable, Codable, Identifiable {
    case center
    case top
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .center: return "Center"
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }

    func normalizedDisplayPoint(marginFraction: CGFloat = 0.08) -> CGPoint {
        switch self {
        case .center:
            return CGPoint(x: 0.5, y: 0.5)
        case .top:
            return CGPoint(x: 0.5, y: marginFraction)
        case .bottom:
            return CGPoint(x: 0.5, y: 1 - marginFraction)
        }
    }
}

/// Supported watermark payload kinds. V1: text and image. Future types (e.g. QR code, PDF page, stamp)
/// extend this enum without replacing `WatermarkSettings` or `WatermarkGeometryEngine`.
enum WatermarkType: String, CaseIterable, Codable, Identifiable {
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        }
    }
}

enum WatermarkLayer: String, CaseIterable, Codable, Identifiable {
    case aboveContent
    case behindContent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aboveContent: return "Above content"
        case .behindContent: return "Behind content"
        }
    }
}

enum WatermarkApplyScope: String, CaseIterable, Codable, Identifiable {
    case allPages
    case currentPage
    case pageRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allPages: return "Entire document"
        case .currentPage: return "Current page"
        case .pageRange: return "Page range"
        }
    }
}

struct WatermarkColor: Equatable, Codable, Hashable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    static let defaultGray = WatermarkColor(red: 0.55, green: 0.55, blue: 0.55)
    static let black = WatermarkColor(red: 0, green: 0, blue: 0)
    static let blue = WatermarkColor(red: 0.1, green: 0.35, blue: 0.85)
    static let red = WatermarkColor(red: 0.85, green: 0.15, blue: 0.15)

    static let presets: [WatermarkColor] = [.defaultGray, .black, .blue, .red]
}

struct WatermarkSettings: Equatable, Codable {
    var isEnabled: Bool
    var watermarkType: WatermarkType
    var text: String
    /// Session image asset reference when `watermarkType` is `.image`.
    var imageAssetID: UUID?
    var opacity: CGFloat
    /// Content width as a fraction of page display width (0–1).
    var normalizedScale: CGFloat
    var color: WatermarkColor
    var rotationDegrees: CGFloat
    var position: WatermarkPosition
    var layer: WatermarkLayer
    var applyScope: WatermarkApplyScope
    var currentPageIndex: Int
    var rangeStart: Int
    var rangeEnd: Int

    static let `default` = WatermarkSettings(
        isEnabled: false,
        watermarkType: .text,
        text: "CONFIDENTIAL",
        imageAssetID: nil,
        opacity: 0.35,
        normalizedScale: 0.35,
        color: .defaultGray,
        rotationDegrees: 45,
        position: .center,
        layer: .aboveContent,
        applyScope: .allPages,
        currentPageIndex: 1,
        rangeStart: 1,
        rangeEnd: 1
    )

    var thumbnailCacheKeySuffix: String {
        guard isEnabled else { return "watermark-off" }
        let assetKey = imageAssetID?.uuidString ?? "none"
        return "watermark-\(watermarkType.rawValue)-\(text)-\(assetKey)-\(opacity)-\(normalizedScale)-\(color.red)-\(color.green)-\(color.blue)-\(rotationDegrees)-\(position.rawValue)-\(layer.rawValue)-\(applyScope.rawValue)-\(currentPageIndex)-\(rangeStart)-\(rangeEnd)"
    }

    var hasRenderableContent: Bool {
        switch watermarkType {
        case .text:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            return imageAssetID != nil
        }
    }

    func shouldApply(toExportIndex exportIndex: Int) -> Bool {
        guard isEnabled, hasRenderableContent else {
            return false
        }

        let pagePosition = exportIndex + 1
        switch applyScope {
        case .allPages:
            return true
        case .currentPage:
            return pagePosition == currentPageIndex
        case .pageRange:
            let lower = max(1, min(rangeStart, rangeEnd))
            let upper = max(rangeStart, rangeEnd)
            return pagePosition >= lower && pagePosition <= upper
        }
    }

    init(
        isEnabled: Bool,
        watermarkType: WatermarkType = .text,
        text: String,
        imageAssetID: UUID? = nil,
        opacity: CGFloat,
        normalizedScale: CGFloat,
        color: WatermarkColor,
        rotationDegrees: CGFloat,
        position: WatermarkPosition,
        layer: WatermarkLayer = .aboveContent,
        applyScope: WatermarkApplyScope,
        currentPageIndex: Int,
        rangeStart: Int,
        rangeEnd: Int
    ) {
        self.isEnabled = isEnabled
        self.watermarkType = watermarkType
        self.text = text
        self.imageAssetID = imageAssetID
        self.opacity = opacity
        self.normalizedScale = normalizedScale
        self.color = color
        self.rotationDegrees = rotationDegrees
        self.position = position
        self.layer = layer
        self.applyScope = applyScope
        self.currentPageIndex = currentPageIndex
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case watermarkType
        case contentType
        case text
        case imageAssetID
        case opacity
        case normalizedScale
        case color
        case rotationDegrees
        case position
        case layer
        case applyScope
        case currentPageIndex
        case rangeStart
        case rangeEnd
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        if let type = try container.decodeIfPresent(WatermarkType.self, forKey: .watermarkType) {
            watermarkType = type
        } else if let legacyType = try container.decodeIfPresent(WatermarkType.self, forKey: .contentType) {
            watermarkType = legacyType
        } else {
            watermarkType = .text
        }
        text = try container.decode(String.self, forKey: .text)
        imageAssetID = try container.decodeIfPresent(UUID.self, forKey: .imageAssetID)
        opacity = try container.decode(CGFloat.self, forKey: .opacity)
        normalizedScale = try container.decode(CGFloat.self, forKey: .normalizedScale)
        color = try container.decode(WatermarkColor.self, forKey: .color)
        rotationDegrees = try container.decode(CGFloat.self, forKey: .rotationDegrees)
        position = try container.decode(WatermarkPosition.self, forKey: .position)
        layer = try container.decodeIfPresent(WatermarkLayer.self, forKey: .layer) ?? .aboveContent
        applyScope = try container.decode(WatermarkApplyScope.self, forKey: .applyScope)
        currentPageIndex = try container.decode(Int.self, forKey: .currentPageIndex)
        rangeStart = try container.decode(Int.self, forKey: .rangeStart)
        rangeEnd = try container.decode(Int.self, forKey: .rangeEnd)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(watermarkType, forKey: .watermarkType)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(imageAssetID, forKey: .imageAssetID)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(normalizedScale, forKey: .normalizedScale)
        try container.encode(color, forKey: .color)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encode(position, forKey: .position)
        try container.encode(layer, forKey: .layer)
        try container.encode(applyScope, forKey: .applyScope)
        try container.encode(currentPageIndex, forKey: .currentPageIndex)
        try container.encode(rangeStart, forKey: .rangeStart)
        try container.encode(rangeEnd, forKey: .rangeEnd)
    }
}
