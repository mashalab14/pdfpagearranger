import CoreGraphics
import UIKit

/// Shared watermark placement and sizing for thumbnails, Page Mode, and PDF export.
enum WatermarkGeometryEngine {
    enum CoordinateSpace {
        case topLeftOrigin
        case pdfMediaBox
    }

    /// Watermark geometry in normalized display space (origin top-left, 0–1).
    struct NormalizedLayout: Equatable {
        let center: CGPoint
        let scale: CGFloat
        let rotationDegrees: CGFloat
        let bounds: CGRect
    }

    /// Concrete watermark placement for a specific render target.
    struct ConcreteLayout: Equatable {
        let center: CGPoint
        let fontSize: CGFloat
        let rotationDegrees: CGFloat
        let bounds: CGRect
    }

    static let marginFraction: CGFloat = 0.08
    static let minimumFontSize: CGFloat = 1

    static func normalizedLayout(
        settings: WatermarkSettings,
        text: String,
        pageRotation: Int,
        mediaBox: CGRect
    ) -> NormalizedLayout? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let displaySize = OverlayGeometryEngine.displayRenderSize(
            for: pageRotation,
            mediaBox: mediaBox
        )
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }

        guard let displayConcrete = buildConcreteLayout(
            settings: settings,
            text: trimmed,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: displaySize,
            coordinateSpace: .topLeftOrigin
        ) else {
            return nil
        }

        let normalizedCenter = settings.position.normalizedDisplayPoint(
            marginFraction: marginFraction
        )

        return NormalizedLayout(
            center: normalizedCenter,
            scale: settings.normalizedScale,
            rotationDegrees: settings.rotationDegrees,
            bounds: CGRect(
                x: displayConcrete.bounds.minX / displaySize.width,
                y: displayConcrete.bounds.minY / displaySize.height,
                width: displayConcrete.bounds.width / displaySize.width,
                height: displayConcrete.bounds.height / displaySize.height
            )
        )
    }

    static func concreteLayout(
        settings: WatermarkSettings,
        text: String,
        pageRotation: Int,
        mediaBox: CGRect,
        renderSize: CGSize,
        coordinateSpace: CoordinateSpace
    ) -> ConcreteLayout? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, renderSize.width > 0, renderSize.height > 0 else {
            return nil
        }

        return buildConcreteLayout(
            settings: settings,
            text: trimmed,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: renderSize,
            coordinateSpace: coordinateSpace
        )
    }

    static func fontSize(
        for text: String,
        normalizedScale: CGFloat,
        renderWidth: CGFloat
    ) -> CGFloat {
        guard renderWidth > 0, normalizedScale > 0 else { return minimumFontSize }

        let targetTextWidth = renderWidth * normalizedScale
        let unitWidth = measuredTextSize(text: text, fontSize: 1).width
        guard unitWidth > 0 else { return minimumFontSize }

        return max(targetTextWidth / unitWidth, minimumFontSize)
    }

    static func measuredTextSize(text: String, fontSize: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize)
        ]
        return (text as NSString).size(withAttributes: attributes)
    }

    private static func buildConcreteLayout(
        settings: WatermarkSettings,
        text: String,
        pageRotation: Int,
        mediaBox: CGRect,
        renderSize: CGSize,
        coordinateSpace: CoordinateSpace
    ) -> ConcreteLayout? {
        let normalizedCenter = settings.position.normalizedDisplayPoint(
            marginFraction: marginFraction
        )
        let normalizedScale = settings.normalizedScale
        let fontSize = fontSize(
            for: text,
            normalizedScale: normalizedScale,
            renderWidth: renderSize.width
        )
        let unitTextSize = measuredTextSize(text: text, fontSize: 1)
        let textWidth = renderSize.width * normalizedScale
        let textHeight = textWidth * unitTextSize.height / max(unitTextSize.width, 1)
        let textSize = CGSize(width: textWidth, height: textHeight)

        let displayCenter = CGPoint(
            x: normalizedCenter.x * renderSize.width,
            y: normalizedCenter.y * renderSize.height
        )
        let concreteBounds = concreteBounds(
            center: displayCenter,
            textSize: textSize,
            rotationDegrees: settings.rotationDegrees
        )

        switch coordinateSpace {
        case .topLeftOrigin:
            return ConcreteLayout(
                center: displayCenter,
                fontSize: fontSize,
                rotationDegrees: settings.rotationDegrees,
                bounds: concreteBounds
            )
        case .pdfMediaBox:
            let pdfCenter = CGPoint(
                x: mediaBox.minX + displayCenter.x,
                y: mediaBox.maxY - displayCenter.y
            )
            let pdfBounds = CGRect(
                x: mediaBox.minX + concreteBounds.minX,
                y: mediaBox.maxY - concreteBounds.maxY,
                width: concreteBounds.width,
                height: concreteBounds.height
            )
            return ConcreteLayout(
                center: pdfCenter,
                fontSize: fontSize,
                rotationDegrees: settings.rotationDegrees,
                bounds: pdfBounds
            )
        }
    }

    private static func concreteBounds(
        center: CGPoint,
        textSize: CGSize,
        rotationDegrees: CGFloat
    ) -> CGRect {
        let halfWidth = textSize.width / 2
        let halfHeight = textSize.height / 2
        let corners = [
            CGPoint(x: -halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: halfHeight),
            CGPoint(x: -halfWidth, y: halfHeight)
        ].map { rotate(point: $0, degrees: rotationDegrees) }
            .map { CGPoint(x: center.x + $0.x, y: center.y + $0.y) }

        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        let minX = xs.min() ?? center.x
        let maxX = xs.max() ?? center.x
        let minY = ys.min() ?? center.y
        let maxY = ys.max() ?? center.y
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func rotate(point: CGPoint, degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)
        return CGPoint(
            x: point.x * cosValue - point.y * sinValue,
            y: point.x * sinValue + point.y * cosValue
        )
    }
}
