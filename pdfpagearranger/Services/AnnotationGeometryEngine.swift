import CoreGraphics
import UIKit

enum AnnotationGeometryEngine {
    enum CoordinateSpace {
        case topLeftOrigin
        case pdfMediaBox
    }

    static func displayRenderSize(for pageRotation: Int, mediaBox: CGRect) -> CGSize {
        OverlayGeometryEngine.displayRenderSize(for: pageRotation, mediaBox: mediaBox)
    }

    static func displayRect(
        from storageRect: PageNormalizedRect,
        pageRotation: Int
    ) -> PageNormalizedRect {
        let center = storageRect.center
        let size = storageRect.size
        let displayCenter = transformPoint(center, pageRotation: normalizeRotation(pageRotation))
        let displaySize = transformSize(size, pageRotation: normalizeRotation(pageRotation))
        return PageNormalizedRect.from(center: displayCenter, size: displaySize)
    }

    static func storageRect(
        from displayRect: PageNormalizedRect,
        pageRotation: Int
    ) -> PageNormalizedRect {
        let center = displayRect.center
        let size = displayRect.size
        let storageCenter = inverseTransformPoint(center, pageRotation: normalizeRotation(pageRotation))
        let storageSize = inverseTransformSize(size, pageRotation: normalizeRotation(pageRotation))
        return PageNormalizedRect.from(center: storageCenter, size: storageSize)
    }

    static func displayPoint(
        from storagePoint: PageNormalizedPoint,
        pageRotation: Int
    ) -> PageNormalizedPoint {
        PageNormalizedPoint(transformPoint(storagePoint.cgPoint, pageRotation: normalizeRotation(pageRotation)))
    }

    static func storagePoint(
        from displayPoint: PageNormalizedPoint,
        pageRotation: Int
    ) -> PageNormalizedPoint {
        PageNormalizedPoint(inverseTransformPoint(displayPoint.cgPoint, pageRotation: normalizeRotation(pageRotation)))
    }

    static func displayRects(
        from storageRects: [PageNormalizedRect],
        pageRotation: Int
    ) -> [PageNormalizedRect] {
        storageRects.map { displayRect(from: $0, pageRotation: pageRotation) }
    }

    static func pixelRect(
        normalizedRect: PageNormalizedRect,
        renderSize: CGSize,
        coordinateSpace: CoordinateSpace,
        mediaBox: CGRect = .zero
    ) -> CGRect {
        let width = normalizedRect.width * Double(renderSize.width)
        let height = normalizedRect.height * Double(renderSize.height)
        switch coordinateSpace {
        case .topLeftOrigin:
            return CGRect(
                x: normalizedRect.x * Double(renderSize.width),
                y: normalizedRect.y * Double(renderSize.height),
                width: width,
                height: height
            )
        case .pdfMediaBox:
            return CGRect(
                x: mediaBox.minX + normalizedRect.x * Double(renderSize.width),
                y: mediaBox.maxY - (normalizedRect.y + normalizedRect.height) * Double(renderSize.height),
                width: width,
                height: height
            )
        }
    }

    static func pixelPoint(
        normalizedPoint: PageNormalizedPoint,
        renderSize: CGSize,
        coordinateSpace: CoordinateSpace,
        mediaBox: CGRect = .zero
    ) -> CGPoint {
        switch coordinateSpace {
        case .topLeftOrigin:
            return CGPoint(
                x: normalizedPoint.x * Double(renderSize.width),
                y: normalizedPoint.y * Double(renderSize.height)
            )
        case .pdfMediaBox:
            return CGPoint(
                x: mediaBox.minX + normalizedPoint.x * Double(renderSize.width),
                y: mediaBox.maxY - normalizedPoint.y * Double(renderSize.height)
            )
        }
    }

    static func clampNormalizedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    static func clampNormalizedRect(_ rect: PageNormalizedRect) -> PageNormalizedRect {
        var clamped = rect
        clamped.width = min(max(clamped.width, 0.001), 1)
        clamped.height = min(max(clamped.height, 0.001), 1)
        clamped.x = min(max(clamped.x, 0), 1 - clamped.width)
        clamped.y = min(max(clamped.y, 0), 1 - clamped.height)
        return clamped
    }

    static func unionAnchorRect(for rects: [PageNormalizedRect]) -> PageNormalizedRect? {
        guard let first = rects.first else { return nil }
        var union = first.cgRect
        for rect in rects.dropFirst() {
            union = union.union(rect.cgRect)
        }
        return PageNormalizedRect(union)
    }

    static func displayTapToStoragePoint(
        tap: CGPoint,
        displayPageSize: CGSize,
        pageRotation: Int
    ) -> PageNormalizedPoint? {
        guard displayPageSize.width > 0, displayPageSize.height > 0 else { return nil }
        let normalizedDisplay = CGPoint(
            x: tap.x / displayPageSize.width,
            y: tap.y / displayPageSize.height
        )
        guard (0...1).contains(normalizedDisplay.x), (0...1).contains(normalizedDisplay.y) else {
            return nil
        }
        return storagePoint(
            from: PageNormalizedPoint(normalizedDisplay),
            pageRotation: pageRotation
        )
    }

    static func isDisplayTapInsidePage(_ tap: CGPoint, displayPageSize: CGSize) -> Bool {
        guard displayPageSize.width > 0, displayPageSize.height > 0 else { return false }
        return tap.x >= 0 && tap.y >= 0 && tap.x <= displayPageSize.width && tap.y <= displayPageSize.height
    }

    private static func transformPoint(_ point: CGPoint, pageRotation: Int) -> CGPoint {
        let x = point.x
        let y = point.y
        switch pageRotation {
        case 90:
            return CGPoint(x: 1 - y, y: x)
        case 180:
            return CGPoint(x: 1 - x, y: 1 - y)
        case 270:
            return CGPoint(x: y, y: 1 - x)
        default:
            return point
        }
    }

    private static func inverseTransformPoint(_ point: CGPoint, pageRotation: Int) -> CGPoint {
        let x = point.x
        let y = point.y
        switch pageRotation {
        case 90:
            return CGPoint(x: y, y: 1 - x)
        case 180:
            return CGPoint(x: 1 - x, y: 1 - y)
        case 270:
            return CGPoint(x: 1 - y, y: x)
        default:
            return point
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
