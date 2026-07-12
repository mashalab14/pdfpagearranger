import CoreGraphics

enum TextOverlayPlacementEngine {
    static func isDisplayTapInsidePage(_ tap: CGPoint, displayPageSize: CGSize) -> Bool {
        SignaturePlacementEngine.isDisplayTapInsidePage(tap, displayPageSize: displayPageSize)
    }

    static func storagePosition(
        forDisplayTap tap: CGPoint,
        displayPageSize: CGSize,
        normalizedOverlaySize: CGSize,
        pageRotation: Int
    ) -> CGPoint {
        SignaturePlacementEngine.storagePosition(
            forDisplayTap: tap,
            displayPageSize: displayPageSize,
            normalizedOverlaySize: normalizedOverlaySize,
            pageRotation: pageRotation
        )
    }
}
