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
        let rotationDegrees: CGFloat
        let bounds: CGRect
        let contentSize: CGSize
        let fontSize: CGFloat?
    }

    static let marginFraction: CGFloat = 0.08
    static let minimumFontSize: CGFloat = 1

    static func normalizedLayout(
        settings: WatermarkSettings,
        pageRotation: Int,
        mediaBox: CGRect,
        image: UIImage? = nil
    ) -> NormalizedLayout? {
        guard settings.hasRenderableContent else { return nil }

        let displaySize = OverlayGeometryEngine.displayRenderSize(
            for: pageRotation,
            mediaBox: mediaBox
        )
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }

        guard let displayConcrete = buildConcreteLayout(
            settings: settings,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: displaySize,
            coordinateSpace: .topLeftOrigin,
            image: image
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
        pageRotation: Int,
        mediaBox: CGRect,
        renderSize: CGSize,
        coordinateSpace: CoordinateSpace,
        image: UIImage? = nil
    ) -> ConcreteLayout? {
        guard settings.hasRenderableContent, renderSize.width > 0, renderSize.height > 0 else {
            return nil
        }

        return buildConcreteLayout(
            settings: settings,
            pageRotation: pageRotation,
            mediaBox: mediaBox,
            renderSize: renderSize,
            coordinateSpace: coordinateSpace,
            image: image
        )
    }

    static func contentSize(
        settings: WatermarkSettings,
        renderWidth: CGFloat,
        image: UIImage?
    ) -> CGSize? {
        guard renderWidth > 0, settings.normalizedScale > 0 else { return nil }

        let width = renderWidth * settings.normalizedScale
        switch settings.contentType {
        case .text:
            let trimmed = settings.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let unitTextSize = measuredTextSize(text: trimmed, fontSize: 1)
            let height = width * unitTextSize.height / max(unitTextSize.width, 1)
            return CGSize(width: width, height: height)
        case .image:
            guard let image, image.size.width > 0 else { return nil }
            let aspect = image.size.height / image.size.width
            return CGSize(width: width, height: width * aspect)
        }
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
        pageRotation: Int,
        mediaBox: CGRect,
        renderSize: CGSize,
        coordinateSpace: CoordinateSpace,
        image: UIImage?
    ) -> ConcreteLayout? {
        guard let contentSize = contentSize(
            settings: settings,
            renderWidth: renderSize.width,
            image: image
        ) else {
            return nil
        }

        let normalizedCenter = settings.position.normalizedDisplayPoint(
            marginFraction: marginFraction
        )
        let fontSize: CGFloat?
        switch settings.contentType {
        case .text:
            let trimmed = settings.text.trimmingCharacters(in: .whitespacesAndNewlines)
            fontSize = Self.fontSize(
                for: trimmed,
                normalizedScale: settings.normalizedScale,
                renderWidth: renderSize.width
            )
        case .image:
            fontSize = nil
        }

        let displayCenter = CGPoint(
            x: normalizedCenter.x * renderSize.width,
            y: normalizedCenter.y * renderSize.height
        )
        let concreteBounds = concreteBounds(
            center: displayCenter,
            contentSize: contentSize,
            rotationDegrees: settings.rotationDegrees
        )

        switch coordinateSpace {
        case .topLeftOrigin:
            return ConcreteLayout(
                center: displayCenter,
                rotationDegrees: settings.rotationDegrees,
                bounds: concreteBounds,
                contentSize: contentSize,
                fontSize: fontSize
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
                rotationDegrees: settings.rotationDegrees,
                bounds: pdfBounds,
                contentSize: contentSize,
                fontSize: fontSize
            )
        }
    }

    private static func concreteBounds(
        center: CGPoint,
        contentSize: CGSize,
        rotationDegrees: CGFloat
    ) -> CGRect {
        let halfWidth = contentSize.width / 2
        let halfHeight = contentSize.height / 2
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

extension WatermarkGeometryEngine.ConcreteLayout {
    var overlayLayout: OverlayGeometryEngine.Layout {
        OverlayGeometryEngine.Layout(
            center: center,
            size: contentSize,
            rotationDegrees: rotationDegrees
        )
    }
}
