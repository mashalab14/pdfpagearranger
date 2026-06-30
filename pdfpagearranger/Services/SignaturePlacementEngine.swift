import CoreGraphics

/// Tap-to-place signature positioning in Page Mode display space.
enum SignaturePlacementEngine {
    /// Converts a tap in page display coordinates to a clamped normalized storage center.
    static func storagePosition(
        forDisplayTap tap: CGPoint,
        displayPageSize: CGSize,
        normalizedOverlaySize: CGSize,
        pageRotation: Int
    ) -> CGPoint {
        guard displayPageSize.width > 0, displayPageSize.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let displayPosition = CGPoint(
            x: tap.x / displayPageSize.width,
            y: tap.y / displayPageSize.height
        )

        let displaySize = OverlayGeometryEngine.displayGeometry(
            position: CGPoint(x: 0.5, y: 0.5),
            size: normalizedOverlaySize,
            objectRotation: 0,
            pageRotation: pageRotation
        ).size

        let clampedDisplay = OverlayInteractionEngine.clampNormalizedCenter(
            displayPosition,
            normalizedSize: displaySize
        )

        return OverlayGeometryEngine.storageGeometry(
            displayPosition: clampedDisplay,
            displaySize: normalizedOverlaySize,
            objectRotation: 0,
            pageRotation: pageRotation
        ).position
    }
}
