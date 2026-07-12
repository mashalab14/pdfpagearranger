import CoreGraphics

enum TextOverlayBoundsEngine {
    static func clampDisplayCenter(
        _ center: CGPoint,
        displaySize: CGSize,
        rotationDegrees: CGFloat
    ) -> CGPoint {
        let bounds = axisAlignedBounds(center: center, size: displaySize, rotationDegrees: rotationDegrees)
        var adjusted = center

        if bounds.minX < 0 {
            adjusted.x += -bounds.minX
        }
        if bounds.maxX > 1 {
            adjusted.x -= bounds.maxX - 1
        }
        if bounds.minY < 0 {
            adjusted.y += -bounds.minY
        }
        if bounds.maxY > 1 {
            adjusted.y -= bounds.maxY - 1
        }

        return OverlayInteractionEngine.clampNormalizedPoint(adjusted)
    }

    static func clampDisplaySize(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, TextOverlayLayoutEngine.minWidthFraction), TextOverlayLayoutEngine.maxWidthFraction),
            height: min(max(size.height, TextOverlayLayoutEngine.minHeightFraction), TextOverlayLayoutEngine.maxHeightFraction)
        )
    }

    static func axisAlignedBounds(
        center: CGPoint,
        size: CGSize,
        rotationDegrees: CGFloat
    ) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let radians = rotationDegrees * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)

        let corners = [
            CGPoint(x: -halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: halfHeight),
            CGPoint(x: -halfWidth, y: halfHeight)
        ].map { point in
            CGPoint(
                x: center.x + point.x * cosValue - point.y * sinValue,
                y: center.y + point.x * sinValue + point.y * cosValue
            )
        }

        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        return (
            minX: xs.min() ?? center.x,
            maxX: xs.max() ?? center.x,
            minY: ys.min() ?? center.y,
            maxY: ys.max() ?? center.y
        )
    }
}
