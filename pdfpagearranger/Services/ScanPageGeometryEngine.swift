import CoreGraphics
import Foundation

enum ScanPageGeometryCornerIndex: Int, CaseIterable, Sendable {
    case topLeft = 0
    case topRight = 1
    case bottomRight = 2
    case bottomLeft = 3
}

enum ScanPageGeometryValidationFailure: Equatable, Error, Sendable {
    case wrongCornerCount
    case outOfBounds
    case collapsedArea
    case crossingEdges
    case duplicateCorners
    case areaTooSmall
}

enum ScanPageGeometryEngine {
    static let cornerCount = 4
    static let defaultBoundsInset: CGFloat = 0.02
    static let minimumNormalizedArea: CGFloat = 0.01
    static let minimumCornerSeparation: CGFloat = 0.03

    static func fullBoundsCorners(inset: CGFloat = defaultBoundsInset) -> [ScanNormalizedPoint] {
        let clampedInset = min(max(inset, 0), 0.49)
        return [
            ScanNormalizedPoint(x: clampedInset, y: clampedInset),
            ScanNormalizedPoint(x: 1 - clampedInset, y: clampedInset),
            ScanNormalizedPoint(x: 1 - clampedInset, y: 1 - clampedInset),
            ScanNormalizedPoint(x: clampedInset, y: 1 - clampedInset)
        ]
    }

    static func initialGeometry(for page: ScanDraftPage) -> ScanPageGeometry {
        var geometry = ScanPageGeometry.default
        geometry.detectedCorners = fullBoundsCorners()
        geometry.perspectiveCorrectionEnabled = page.sourceType == .photos
        return geometry
    }

    static func needsAutomaticDetection(for page: ScanDraftPage) -> Bool {
        guard page.sourceType == .photos else { return false }
        return page.geometry.userAdjustedCorners == nil && page.geometry.detectedCorners == nil
    }

    static func clampedCorners(_ corners: [ScanNormalizedPoint]) -> [ScanNormalizedPoint] {
        corners.map { corner in
            ScanNormalizedPoint(
                x: min(max(corner.x, 0), 1),
                y: min(max(corner.y, 0), 1)
            )
        }
    }

    static func validateCorners(_ corners: [ScanNormalizedPoint]) -> Result<[ScanNormalizedPoint], ScanPageGeometryValidationFailure> {
        guard corners.count == cornerCount else {
            return .failure(.wrongCornerCount)
        }

        let clamped = clampedCorners(corners)
        if clamped.contains(where: { $0.x < 0 || $0.x > 1 || $0.y < 0 || $0.y > 1 }) {
            return .failure(.outOfBounds)
        }

        for index in 0..<cornerCount {
            let current = clamped[index]
            let next = clamped[(index + 1) % cornerCount]
            if distance(current, next) < minimumCornerSeparation {
                return .failure(.duplicateCorners)
            }
        }

        if !isConvexQuadrilateral(clamped) {
            return .failure(.crossingEdges)
        }

        let area = normalizedQuadrilateralArea(clamped)
        if area <= 0 {
            return .failure(.collapsedArea)
        }
        if area < minimumNormalizedArea {
            return .failure(.areaTooSmall)
        }

        return .success(clamped)
    }

    static func aspectFitDisplayRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height
        let scale = min(widthScale, heightScale)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )
        return CGRect(origin: origin, size: fittedSize)
    }

    static func normalizedToPixel(_ point: ScanNormalizedPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x * imageSize.width, y: point.y * imageSize.height)
    }

    static func pixelToNormalized(_ point: CGPoint, imageSize: CGSize) -> ScanNormalizedPoint {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return ScanNormalizedPoint(x: 0, y: 0)
        }
        return ScanNormalizedPoint(
            x: point.x / imageSize.width,
            y: point.y / imageSize.height
        )
    }

    static func normalizedToPreview(
        _ point: ScanNormalizedPoint,
        displayRect: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        let pixel = normalizedToPixel(point, imageSize: imageSize)
        let scaleX = displayRect.width / imageSize.width
        let scaleY = displayRect.height / imageSize.height
        return CGPoint(
            x: displayRect.minX + pixel.x * scaleX,
            y: displayRect.minY + pixel.y * scaleY
        )
    }

    static func previewToNormalized(
        _ point: CGPoint,
        displayRect: CGRect,
        imageSize: CGSize
    ) -> ScanNormalizedPoint {
        guard displayRect.width > 0, displayRect.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return ScanNormalizedPoint(x: 0, y: 0)
        }

        let pixel = CGPoint(
            x: (point.x - displayRect.minX) / displayRect.width * imageSize.width,
            y: (point.y - displayRect.minY) / displayRect.height * imageSize.height
        )
        return pixelToNormalized(pixel, imageSize: imageSize)
    }

    static func normalizedToCoreImage(
        _ point: ScanNormalizedPoint,
        imageSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: point.x * imageSize.width,
            y: (1 - point.y) * imageSize.height
        )
    }

    static func coreImageToNormalized(_ point: CGPoint, imageSize: CGSize) -> ScanNormalizedPoint {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return ScanNormalizedPoint(x: 0, y: 0)
        }
        return ScanNormalizedPoint(
            x: point.x / imageSize.width,
            y: 1 - (point.y / imageSize.height)
        )
    }

    static func distance(_ lhs: ScanNormalizedPoint, _ rhs: ScanNormalizedPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func normalizedQuadrilateralArea(_ corners: [ScanNormalizedPoint]) -> CGFloat {
        var sum: CGFloat = 0
        for index in 0..<corners.count {
            let current = corners[index]
            let next = corners[(index + 1) % corners.count]
            sum += (current.x * next.y) - (next.x * current.y)
        }
        return abs(sum) * 0.5
    }

    private static func isConvexQuadrilateral(_ corners: [ScanNormalizedPoint]) -> Bool {
        guard corners.count == cornerCount else { return false }

        var sign: CGFloat = 0
        for index in 0..<cornerCount {
            let a = corners[index]
            let b = corners[(index + 1) % cornerCount]
            let c = corners[(index + 2) % cornerCount]
            let cross = crossProduct(a, b, c)
            if abs(cross) < 0.000_001 { continue }
            if sign == 0 {
                sign = cross
            } else if sign * cross < 0 {
                return false
            }
        }
        return true
    }

    private static func crossProduct(
        _ a: ScanNormalizedPoint,
        _ b: ScanNormalizedPoint,
        _ c: ScanNormalizedPoint
    ) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
}
