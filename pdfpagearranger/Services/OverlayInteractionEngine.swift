import CoreGraphics

/// Pure math for overlay drag and resize interactions in Page Mode.
enum OverlayInteractionEngine {
    static let minNormalizedSize: CGFloat = 0.08
    static let maxNormalizedSize: CGFloat = 0.95
    static let minMagnificationScale: CGFloat = 0.15

    static func dragDisplayCenter(
        startCenter: CGPoint,
        translation: CGSize,
        canvasScale: CGFloat
    ) -> CGPoint {
        let adjustedScale = max(canvasScale, 0.01)
        return CGPoint(
            x: startCenter.x + translation.width / adjustedScale,
            y: startCenter.y + translation.height / adjustedScale
        )
    }

    static func uniformResizedLayoutSize(
        startSize: CGSize,
        translation: CGSize,
        canvasScale: CGFloat,
        minSize: CGSize,
        maxSize: CGSize
    ) -> CGSize {
        let adjustedScale = max(canvasScale, 0.01)
        let dx = translation.width / adjustedScale
        let dy = translation.height / adjustedScale

        let scaleX = (startSize.width + dx) / max(startSize.width, 0.01)
        let scaleY = (startSize.height + dy) / max(startSize.height, 0.01)
        let uniformScale = max(max(scaleX, scaleY), 0.01)

        var width = startSize.width * uniformScale
        var height = startSize.height * uniformScale

        width = min(max(width, minSize.width), maxSize.width)
        height = min(max(height, minSize.height), maxSize.height)

        let aspect = startSize.width / max(startSize.height, 0.01)
        if width / max(height, 0.01) > aspect {
            width = height * aspect
        } else {
            height = width / aspect
        }

        width = min(max(width, minSize.width), maxSize.width)
        height = min(max(height, minSize.height), maxSize.height)

        return CGSize(width: width, height: height)
    }

    static func magnificationResizedNormalizedSize(
        startNormalizedSize: CGSize,
        magnification: CGFloat,
        minNormalized: CGFloat = minNormalizedSize,
        maxNormalized: CGFloat = maxNormalizedSize
    ) -> CGSize {
        let clampedMagnification = max(magnification, minMagnificationScale)
        let aspect = startNormalizedSize.width / max(startNormalizedSize.height, 0.01)

        var width = startNormalizedSize.width * clampedMagnification
        var height = startNormalizedSize.height * clampedMagnification

        width = min(max(width, minNormalized), maxNormalized)
        height = min(max(height, minNormalized), maxNormalized)

        if width / max(height, 0.01) > aspect {
            width = height * aspect
        } else {
            height = width / aspect
        }

        width = min(max(width, minNormalized), maxNormalized)
        height = min(max(height, minNormalized), maxNormalized)

        return CGSize(width: width, height: height)
    }

    static func clampNormalizedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    static func clampNormalizedCenter(
        _ center: CGPoint,
        normalizedSize: CGSize
    ) -> CGPoint {
        let halfWidth = normalizedSize.width / 2
        let halfHeight = normalizedSize.height / 2
        let minX = min(halfWidth, 0.5)
        let maxX = max(1 - halfWidth, 0.5)
        let minY = min(halfHeight, 0.5)
        let maxY = max(1 - halfHeight, 0.5)
        return CGPoint(
            x: min(max(center.x, minX), maxX),
            y: min(max(center.y, minY), maxY)
        )
    }
}
