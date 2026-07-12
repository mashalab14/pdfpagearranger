import CoreGraphics

enum TextOverlayMenuEngine {
    static func anchorPoint(
        for layout: OverlayGeometryEngine.Layout,
        pageSize: CGSize
    ) -> CGPoint {
        let y = max(layout.topLeftBounds.minY - ContextualControlMetrics.toolbarVisibleHeight / 2 - 8, 20)
        let x = min(max(layout.center.x, 80), pageSize.width - 80)
        return CGPoint(x: x, y: y)
    }
}
