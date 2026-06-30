import UIKit

/// Metadata captured when placing a signature from the library or capture flow.
struct SignaturePlacementContext: Equatable {
    let sourceImage: UIImage
    let librarySourceID: UUID?
    let baselineInkColor: SignatureInkColor
    let baselineStrokeThickness: SignatureInkThickness

    static func fromLibraryAsset(_ asset: SignatureAsset, image: UIImage) -> SignaturePlacementContext {
        SignaturePlacementContext(
            sourceImage: image,
            librarySourceID: asset.id,
            baselineInkColor: .defaultInk,
            baselineStrokeThickness: asset.strokeThickness ?? .defaultThickness
        )
    }

    static func fromCapturedImage(
        _ image: UIImage,
        librarySourceID: UUID?,
        strokeThickness: SignatureInkThickness,
        inkColor: SignatureInkColor = .defaultInk
    ) -> SignaturePlacementContext {
        SignaturePlacementContext(
            sourceImage: image,
            librarySourceID: librarySourceID,
            baselineInkColor: inkColor,
            baselineStrokeThickness: strokeThickness
        )
    }
}
