import CoreGraphics
import UIKit

/// Shared overlay coordinate mapping for Page Mode, thumbnails, and PDF export.
enum OverlayGeometryEngine {
    /// Normalized overlay geometry in rotated display space (0–1 center position and size fractions).
    struct NormalizedGeometry {
        var position: CGPoint
        var size: CGSize
        var rotation: CGFloat
    }

    /// Concrete overlay placement in a render target's coordinate space.
    struct Layout {
        let center: CGPoint
        let size: CGSize
        let rotationDegrees: CGFloat

        var topLeftBounds: CGRect {
            CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
    }

    enum CoordinateSpace {
        /// SwiftUI Page Mode and UIImage compositing (origin top-left).
        case topLeftOrigin
        /// PDF media box (origin bottom-left).
        case pdfMediaBox
    }

    // MARK: - Normalized transforms

    static func displayGeometry(
        position: CGPoint,
        size: CGSize,
        objectRotation: CGFloat,
        pageRotation: Int
    ) -> NormalizedGeometry {
        let normalized = normalizeRotation(pageRotation)
        return NormalizedGeometry(
            position: transformPosition(position, pageRotation: normalized),
            size: transformSize(size, pageRotation: normalized),
            rotation: objectRotation + CGFloat(normalized)
        )
    }

    static func storageGeometry(
        displayPosition: CGPoint,
        displaySize: CGSize,
        objectRotation: CGFloat,
        pageRotation: Int
    ) -> NormalizedGeometry {
        let normalized = normalizeRotation(pageRotation)
        return NormalizedGeometry(
            position: inverseTransformPosition(displayPosition, pageRotation: normalized),
            size: inverseTransformSize(displaySize, pageRotation: normalized),
            rotation: objectRotation - CGFloat(normalized)
        )
    }

    static func displayRenderSize(for pageRotation: Int, mediaBox: CGRect) -> CGSize {
        let normalized = normalizeRotation(pageRotation)
        switch normalized {
        case 90, 270:
            return CGSize(width: mediaBox.height, height: mediaBox.width)
        default:
            return mediaBox.size
        }
    }

    // MARK: - Concrete layouts

    static func pageModeLayout(
        for object: PageObject,
        pageRotation: Int,
        renderSize: CGSize
    ) -> Layout {
        layout(
            for: object,
            pageRotation: pageRotation,
            renderSize: renderSize,
            mediaBox: .zero,
            coordinateSpace: .topLeftOrigin
        )
    }

    static func thumbnailLayout(
        for object: PageObject,
        pageRotation: Int,
        renderSize: CGSize
    ) -> Layout {
        pageModeLayout(for: object, pageRotation: pageRotation, renderSize: renderSize)
    }

    static func pdfLayout(
        for object: PageObject,
        pageRotation: Int,
        mediaBox: CGRect
    ) -> Layout {
        let displaySize = displayRenderSize(for: pageRotation, mediaBox: mediaBox)
        return layout(
            for: object,
            pageRotation: pageRotation,
            renderSize: displaySize,
            mediaBox: mediaBox,
            coordinateSpace: .pdfMediaBox
        )
    }

    static func layout(
        for object: PageObject,
        pageRotation: Int,
        renderSize: CGSize,
        mediaBox: CGRect,
        coordinateSpace: CoordinateSpace
    ) -> Layout {
        let display = displayGeometry(
            position: object.position,
            size: object.size,
            objectRotation: object.rotation,
            pageRotation: pageRotation
        )

        let width = display.size.width * renderSize.width
        let height = display.size.height * renderSize.height

        switch coordinateSpace {
        case .topLeftOrigin:
            return Layout(
                center: CGPoint(
                    x: display.position.x * renderSize.width,
                    y: display.position.y * renderSize.height
                ),
                size: CGSize(width: width, height: height),
                rotationDegrees: display.rotation
            )
        case .pdfMediaBox:
            return Layout(
                center: CGPoint(
                    x: mediaBox.minX + display.position.x * renderSize.width,
                    y: mediaBox.maxY - display.position.y * renderSize.height
                ),
                size: CGSize(width: width, height: height),
                rotationDegrees: display.rotation
            )
        }
    }

    // MARK: - Drawing helpers

    static func drawUIImage(
        _ image: UIImage,
        layout: Layout,
        opacity: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(opacity)

        if layout.rotationDegrees != 0 {
            context.translateBy(x: layout.center.x, y: layout.center.y)
            context.rotate(by: layout.rotationDegrees * .pi / 180)
            context.translateBy(x: -layout.size.width / 2, y: -layout.size.height / 2)
            image.draw(in: CGRect(origin: .zero, size: layout.size))
        } else {
            image.draw(in: layout.topLeftBounds)
        }

        context.restoreGState()
    }

    static func drawPDFImage(
        _ image: CGImage,
        layout: Layout,
        opacity: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.setAlpha(opacity)

        if layout.rotationDegrees != 0 {
            context.translateBy(x: layout.center.x, y: layout.center.y)
            context.rotate(by: -layout.rotationDegrees * .pi / 180)
            flipDrawPDFImage(
                image,
                in: CGRect(
                    x: -layout.size.width / 2,
                    y: -layout.size.height / 2,
                    width: layout.size.width,
                    height: layout.size.height
                ),
                context: context
            )
        } else {
            flipDrawPDFImage(
                image,
                in: layout.topLeftBounds,
                context: context
            )
        }

        context.restoreGState()
    }

    private static func flipDrawPDFImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    // MARK: - Rotation math

    private static func transformPosition(_ position: CGPoint, pageRotation: Int) -> CGPoint {
        let x = position.x
        let y = position.y
        switch pageRotation {
        case 90:
            return CGPoint(x: 1 - y, y: x)
        case 180:
            return CGPoint(x: 1 - x, y: 1 - y)
        case 270:
            return CGPoint(x: y, y: 1 - x)
        default:
            return position
        }
    }

    private static func inverseTransformPosition(_ position: CGPoint, pageRotation: Int) -> CGPoint {
        let x = position.x
        let y = position.y
        switch pageRotation {
        case 90:
            return CGPoint(x: y, y: 1 - x)
        case 180:
            return CGPoint(x: 1 - x, y: 1 - y)
        case 270:
            return CGPoint(x: 1 - y, y: x)
        default:
            return position
        }
    }

    private static func transformSize(_ size: CGSize, pageRotation: Int) -> CGSize {
        switch pageRotation {
        case 90, 270:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }

    private static func inverseTransformSize(_ size: CGSize, pageRotation: Int) -> CGSize {
        transformSize(size, pageRotation: pageRotation)
    }

    private static func normalizeRotation(_ rotation: Int) -> Int {
        let value = rotation % 360
        return value < 0 ? value + 360 : value
    }
}

extension PageObject {
    func displayGeometry(pageRotation: Int) -> OverlayGeometryEngine.NormalizedGeometry {
        OverlayGeometryEngine.displayGeometry(
            position: position,
            size: size,
            objectRotation: rotation,
            pageRotation: pageRotation
        )
    }

    func applyingStorageGeometry(
        _ geometry: OverlayGeometryEngine.NormalizedGeometry,
        pageRotation: Int
    ) -> PageObject {
        var copy = self
        let stored = OverlayGeometryEngine.storageGeometry(
            displayPosition: geometry.position,
            displaySize: geometry.size,
            objectRotation: geometry.rotation,
            pageRotation: pageRotation
        )
        copy.position = stored.position
        copy.size = stored.size
        copy.rotation = stored.rotation
        return copy
    }
}
