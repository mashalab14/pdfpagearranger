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
    var text: String
    var opacity: CGFloat
    /// Text width as a fraction of page display width (0–1).
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
        text: "CONFIDENTIAL",
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
        return "watermark-\(text)-\(opacity)-\(normalizedScale)-\(color.red)-\(color.green)-\(color.blue)-\(rotationDegrees)-\(position.rawValue)-\(layer.rawValue)-\(applyScope.rawValue)-\(currentPageIndex)-\(rangeStart)-\(rangeEnd)"
    }

    func shouldApply(toExportIndex exportIndex: Int) -> Bool {
        guard isEnabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
        text: String,
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
        self.text = text
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        text = try container.decode(String.self, forKey: .text)
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
}
