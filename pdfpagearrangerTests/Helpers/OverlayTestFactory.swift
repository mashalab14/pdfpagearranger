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

    static func makeSignatureOverlay(
        pageItemID: UUID,
        assetID: UUID = UUID(),
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        size: CGSize = CGSize(width: 0.30, height: 0.12),
        rotation: CGFloat = 0,
        opacity: CGFloat = 1,
        zIndex: Int = 0
    ) -> PageObject {
        PageObject(
            pageItemID: pageItemID,
            type: .signature,
            position: position,
            size: size,
            rotation: rotation,
            opacity: opacity,
            zIndex: zIndex,
            imageAssetID: assetID
        )
    }

    static func makeSignatureImage(size: CGSize = CGSize(width: 120, height: 40)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let path = UIBezierPath()
            path.move(to: CGPoint(x: 8, y: size.height * 0.6))
            path.addCurve(
                to: CGPoint(x: size.width - 8, y: size.height * 0.45),
                controlPoint1: CGPoint(x: size.width * 0.3, y: size.height * 0.2),
                controlPoint2: CGPoint(x: size.width * 0.65, y: size.height * 0.85)
            )
            UIColor.black.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
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

    @MainActor
    static func seedSignature(
        on viewModel: PDFEditorViewModel,
        pageItemID: UUID,
        pageAspectRatio: CGFloat = 612.0 / 792.0
    ) -> PageObject {
        viewModel.addSignatureOverlay(
            to: pageItemID,
            image: makeSignatureImage(),
            pageAspectRatio: pageAspectRatio
        )
        return viewModel.overlayObjects(for: pageItemID).last!
    }
}
