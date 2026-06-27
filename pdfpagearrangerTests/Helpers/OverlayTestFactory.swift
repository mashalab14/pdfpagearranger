import CoreGraphics
import UIKit
@testable import pdfpagearranger

enum OverlayTestFactory {
    static func makeImageOverlay(
        pageItemID: UUID,
        assetID: UUID = UUID(),
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        size: CGSize = CGSize(width: 0.2, height: 0.2),
        rotation: CGFloat = 0,
        opacity: CGFloat = 1,
        zIndex: Int = 0
    ) -> PageObject {
        PageObject(
            pageItemID: pageItemID,
            type: .image,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            zIndex: zIndex,
            imageAssetID: assetID
        )
    }

    static func makeImageAssets(for overlays: [PageObject], color: UIColor = .green) -> [UUID: UIImage] {
        var assets: [UUID: UIImage] = [:]
        for overlay in overlays {
            if let assetID = overlay.imageAssetID {
                assets[assetID] = PDFTestFactory.makeTestImage(color: color)
            }
        }
        return assets
    }

    @MainActor
    static func seedOverlay(
        on viewModel: PDFEditorViewModel,
        pageItemID: UUID,
        pageAspectRatio: CGFloat = 612.0 / 792.0,
        color: UIColor = .green
    ) -> PageObject {
        viewModel.addImageOverlay(
            to: pageItemID,
            image: PDFTestFactory.makeTestImage(color: color),
            pageAspectRatio: pageAspectRatio
        )
        return viewModel.overlayObjects(for: pageItemID).last!
    }
}
