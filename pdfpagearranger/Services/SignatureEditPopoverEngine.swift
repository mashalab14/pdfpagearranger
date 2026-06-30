import CoreGraphics

enum SignatureEditPopoverEngine {
    static let popoverSize = CGSize(width: 248, height: 96)
    static let edgePadding: CGFloat = 8
    static let verticalSpacing: CGFloat = 12

    static func anchorPoint(
        for layout: OverlayGeometryEngine.Layout,
        pageSize: CGSize,
        popoverSize: CGSize = popoverSize
    ) -> CGPoint {
        let bounds = layout.topLeftBounds
        let halfWidth = popoverSize.width / 2
        let halfHeight = popoverSize.height / 2

        let x = min(
            max(bounds.midX, halfWidth + edgePadding),
            pageSize.width - halfWidth - edgePadding
        )

        let minCenterY = halfHeight + edgePadding
        let maxCenterY = pageSize.height - halfHeight - edgePadding

        let aboveCenterY = bounds.minY - verticalSpacing - halfHeight
        let belowCenterY = bounds.maxY + verticalSpacing + halfHeight

        let aboveFits = aboveCenterY >= minCenterY
        let belowFits = belowCenterY <= maxCenterY

        let y: CGFloat
        if aboveFits {
            y = aboveCenterY
        } else if belowFits {
            y = belowCenterY
        } else if aboveCenterY - minCenterY >= maxCenterY - belowCenterY {
            y = minCenterY
        } else {
            y = maxCenterY
        }

        return CGPoint(x: x, y: y)
    }
}
