import CoreGraphics
import Foundation
import UIKit

/// Normalized rectangle on the unrotated page (origin top-left, values 0–1).
struct PageNormalizedRect: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    var center: CGPoint {
        CGPoint(x: x + width / 2, y: y + height / 2)
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    static func from(center: CGPoint, size: CGSize) -> PageNormalizedRect {
        PageNormalizedRect(
            x: Double(center.x - size.width / 2),
            y: Double(center.y - size.height / 2),
            width: Double(size.width),
            height: Double(size.height)
        )
    }
}

/// Normalized point on the unrotated page (origin top-left, values 0–1).
struct PageNormalizedPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    init(_ point: CGPoint) {
        x = Double(point.x)
        y = Double(point.y)
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

enum PageAnnotationKind: String, Codable, Equatable, Sendable {
    case highlight
    case drawing
    case stickyNote
    case textComment
}

enum HighlightPresetColor: String, Codable, CaseIterable, Sendable {
    case yellow
    case green
    case blue
    case pink
    case orange

    var rgba: SignatureInkRGBA {
        switch self {
        case .yellow: SignatureInkRGBA(red: 1, green: 0.92, blue: 0.23, alpha: 1)
        case .green: SignatureInkRGBA(red: 0.4, green: 0.85, blue: 0.45, alpha: 1)
        case .blue: SignatureInkRGBA(red: 0.35, green: 0.65, blue: 1, alpha: 1)
        case .pink: SignatureInkRGBA(red: 1, green: 0.55, blue: 0.75, alpha: 1)
        case .orange: SignatureInkRGBA(red: 1, green: 0.65, blue: 0.2, alpha: 1)
        }
    }

    static let defaultPreset: HighlightPresetColor = .yellow
    static let defaultOpacity: CGFloat = 0.35
}

enum DrawingPresetColor: String, Codable, CaseIterable, Sendable {
    case black
    case red
    case blue
    case green
    case yellow

    var rgba: SignatureInkRGBA {
        switch self {
        case .black: SignatureInkRGBA(red: 0, green: 0, blue: 0, alpha: 1)
        case .red: SignatureInkRGBA(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
        case .blue: SignatureInkRGBA(red: 0.1, green: 0.4, blue: 0.95, alpha: 1)
        case .green: SignatureInkRGBA(red: 0.1, green: 0.65, blue: 0.25, alpha: 1)
        case .yellow: SignatureInkRGBA(red: 0.95, green: 0.8, blue: 0.05, alpha: 1)
        }
    }
}

enum DrawingThicknessPreset: String, Codable, CaseIterable, Sendable {
    case thin
    case medium
    case thick

    /// Normalized line width as a fraction of page width.
    var normalizedWidth: CGFloat {
        switch self {
        case .thin: 0.0025
        case .medium: 0.0045
        case .thick: 0.0075
        }
    }
}

enum DrawingToolKind: String, Codable, Equatable, Sendable {
    case pen
}

struct DrawingStroke: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var normalizedPoints: [PageNormalizedPoint]
    var colorRGBA: SignatureInkRGBA
    var normalizedLineWidth: Double
    var opacity: Double
    var tool: DrawingToolKind

    init(
        id: UUID = UUID(),
        normalizedPoints: [PageNormalizedPoint],
        colorRGBA: SignatureInkRGBA,
        normalizedLineWidth: Double,
        opacity: Double = 1,
        tool: DrawingToolKind = .pen
    ) {
        self.id = id
        self.normalizedPoints = normalizedPoints
        self.colorRGBA = colorRGBA
        self.normalizedLineWidth = normalizedLineWidth
        self.opacity = opacity
        self.tool = tool
    }
}

struct PageAnnotation: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let pageItemID: UUID
    let kind: PageAnnotationKind
    var createdAt: Date

    // Highlight + text comment anchors
    var normalizedRects: [PageNormalizedRect]?
    var selectedText: String?

    // Highlight
    var highlightColor: HighlightPresetColor?
    var highlightOpacity: Double?

    // Text comment
    var commentText: String?
    var linkedHighlightID: UUID?
    var anchorColorRGBA: SignatureInkRGBA?

    // Drawing
    var strokes: [DrawingStroke]?

    // Sticky note
    var normalizedPosition: PageNormalizedPoint?
    var noteText: String?
    var noteColorRGBA: SignatureInkRGBA?

    init(
        id: UUID = UUID(),
        pageItemID: UUID,
        kind: PageAnnotationKind,
        createdAt: Date = Date(),
        normalizedRects: [PageNormalizedRect]? = nil,
        selectedText: String? = nil,
        highlightColor: HighlightPresetColor? = nil,
        highlightOpacity: Double? = nil,
        commentText: String? = nil,
        linkedHighlightID: UUID? = nil,
        anchorColorRGBA: SignatureInkRGBA? = nil,
        strokes: [DrawingStroke]? = nil,
        normalizedPosition: PageNormalizedPoint? = nil,
        noteText: String? = nil,
        noteColorRGBA: SignatureInkRGBA? = nil
    ) {
        self.id = id
        self.pageItemID = pageItemID
        self.kind = kind
        self.createdAt = createdAt
        self.normalizedRects = normalizedRects
        self.selectedText = selectedText
        self.highlightColor = highlightColor
        self.highlightOpacity = highlightOpacity
        self.commentText = commentText
        self.linkedHighlightID = linkedHighlightID
        self.anchorColorRGBA = anchorColorRGBA
        self.strokes = strokes
        self.normalizedPosition = normalizedPosition
        self.noteText = noteText
        self.noteColorRGBA = noteColorRGBA
    }

    func duplicated(forPageItemID newPageItemID: UUID) -> PageAnnotation {
        PageAnnotation(
            pageItemID: newPageItemID,
            kind: kind,
            createdAt: createdAt,
            normalizedRects: normalizedRects,
            selectedText: selectedText,
            highlightColor: highlightColor,
            highlightOpacity: highlightOpacity,
            commentText: commentText,
            linkedHighlightID: linkedHighlightID,
            anchorColorRGBA: anchorColorRGBA,
            strokes: strokes?.map {
                DrawingStroke(
                    normalizedPoints: $0.normalizedPoints,
                    colorRGBA: $0.colorRGBA,
                    normalizedLineWidth: $0.normalizedLineWidth,
                    opacity: $0.opacity,
                    tool: $0.tool
                )
            },
            normalizedPosition: normalizedPosition,
            noteText: noteText,
            noteColorRGBA: noteColorRGBA
        )
    }
}

enum DrawingSettings {
    static let colorKey = "annotationDrawingColor"
    static let thicknessKey = "annotationDrawingThickness"

    static func storedColor(in defaults: UserDefaults = .standard) -> DrawingPresetColor {
        guard let raw = defaults.string(forKey: colorKey),
              let value = DrawingPresetColor(rawValue: raw) else {
            return .black
        }
        return value
    }

    static func setStoredColor(_ color: DrawingPresetColor, in defaults: UserDefaults = .standard) {
        defaults.set(color.rawValue, forKey: colorKey)
    }

    static func storedThickness(in defaults: UserDefaults = .standard) -> DrawingThicknessPreset {
        guard let raw = defaults.string(forKey: thicknessKey),
              let value = DrawingThicknessPreset(rawValue: raw) else {
            return .medium
        }
        return value
    }

    static func setStoredThickness(_ thickness: DrawingThicknessPreset, in defaults: UserDefaults = .standard) {
        defaults.set(thickness.rawValue, forKey: thicknessKey)
    }
}

enum StickyNoteStyle {
    static let defaultColor = SignatureInkRGBA(red: 1, green: 0.95, blue: 0.55, alpha: 1)
    static let markerSizeFraction: CGFloat = 0.045
}

enum TextCommentStyle {
    static let anchorOpacity: CGFloat = 0.2
    static let defaultAnchorColor = SignatureInkRGBA(red: 0.2, green: 0.45, blue: 0.95, alpha: 1)
}
