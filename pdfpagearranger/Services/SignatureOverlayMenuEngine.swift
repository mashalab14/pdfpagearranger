import CoreGraphics

enum SignatureOverlayMenuEngine {
    static var menuWidth: CGFloat { SignatureContextualUIMetrics.signatureToolbarWidth }
    static let verticalOffset: CGFloat = 40
    static let horizontalPadding: CGFloat = 8
    static let minimumTopPadding: CGFloat = 24

    static func anchorPoint(
        for layout: OverlayGeometryEngine.Layout,
        pageSize: CGSize
    ) -> CGPoint {
        let bounds = layout.topLeftBounds
        let halfWidth = menuWidth / 2
        let x = min(
            max(bounds.midX, halfWidth + horizontalPadding),
            pageSize.width - halfWidth - horizontalPadding
        )
        let y = max(bounds.minY - verticalOffset, minimumTopPadding)
        return CGPoint(x: x, y: y)
    }
}
