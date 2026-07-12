import CoreGraphics
import Foundation
import UIKit

enum PageObjectType: String, Codable, CaseIterable {
    case image
    case text
    case signature
}

struct PageObject: Identifiable, Equatable, Codable {
    let id: UUID
    let pageItemID: UUID
    var type: PageObjectType
    /// Normalized center position on the page (0–1).
    var position: CGPoint
    /// Normalized size relative to page width and height (0–1).
    var size: CGSize
    var rotation: CGFloat
    var opacity: CGFloat
    var zIndex: Int
    var imageAssetID: UUID?
    /// Library asset this placement originated from, when applicable.
    var signatureLibrarySourceID: UUID?
    /// Immutable raster used to re-render placed signature appearance.
    var signatureSourceImageAssetID: UUID?
    var signatureInkColor: SignatureInkColor?
    var signatureCustomInkRGBA: SignatureInkRGBA?
    var signatureStrokeThickness: SignatureInkThickness?
    var signatureStrokeWidthPoints: Int?
    var signatureBaselineInkColor: SignatureInkColor?
    var signatureBaselineStrokeThickness: SignatureInkThickness?
    var textContent: String?
    var textFontSizePoints: CGFloat?
    var textColorRGBA: SignatureInkRGBA?
    var textBold: Bool?
    var textListMode: TextOverlayListMode?

    var usesRasterImageAsset: Bool {
        (type == .image || type == .signature) && imageAssetID != nil
    }

    var isTextOverlay: Bool {
        type == .text
    }

    var effectiveSignatureInkColor: SignatureInkColor {
        signatureInkColor ?? signatureBaselineInkColor ?? .defaultInk
    }

    var effectiveSignatureInkUIColor: UIColor {
        if let custom = signatureCustomInkRGBA {
            return custom.uiColor
        }
        return effectiveSignatureInkColor.uiColor
    }

    var effectiveSignatureStrokeThickness: SignatureInkThickness {
        PlacedSignatureStrokeWidth.libraryThickness(for: effectiveSignatureStrokeWidthPoints)
    }

    var effectiveSignatureStrokeWidthPoints: Int {
        if let points = signatureStrokeWidthPoints {
            return PlacedSignatureStrokeWidth.clamped(points)
        }
        return PlacedSignatureStrokeWidth.points(
            for: signatureBaselineStrokeThickness ?? .defaultThickness
        )
    }

    var baselineSignatureStrokeWidthPoints: Int {
        PlacedSignatureStrokeWidth.points(
            for: signatureBaselineStrokeThickness ?? .defaultThickness
        )
    }

    var signatureAppearanceDiffersFromBaseline: Bool {
        guard type == .signature,
              signatureBaselineInkColor != nil,
              signatureBaselineStrokeThickness != nil else {
            return false
        }
        return inkColorDiffersFromBaseline || thicknessDiffersFromBaseline
    }

    private var inkColorDiffersFromBaseline: Bool {
        guard let baselineColor = signatureBaselineInkColor else { return false }
        if signatureCustomInkRGBA != nil {
            return true
        }
        return effectiveSignatureInkColor != baselineColor
    }

    private var thicknessDiffersFromBaseline: Bool {
        guard signatureBaselineStrokeThickness != nil else { return false }
        return effectiveSignatureStrokeWidthPoints != baselineSignatureStrokeWidthPoints
    }

    var canSavePlacedSignatureToLibrary: Bool {
        signatureLibrarySourceID != nil && signatureAppearanceDiffersFromBaseline
    }

    init(
        id: UUID = UUID(),
        pageItemID: UUID,
        type: PageObjectType,
        position: CGPoint,
        size: CGSize,
        rotation: CGFloat = 0,
        opacity: CGFloat = 1,
        zIndex: Int = 0,
        imageAssetID: UUID? = nil,
        signatureLibrarySourceID: UUID? = nil,
        signatureSourceImageAssetID: UUID? = nil,
        signatureInkColor: SignatureInkColor? = nil,
        signatureCustomInkRGBA: SignatureInkRGBA? = nil,
        signatureStrokeThickness: SignatureInkThickness? = nil,
        signatureStrokeWidthPoints: Int? = nil,
        signatureBaselineInkColor: SignatureInkColor? = nil,
        signatureBaselineStrokeThickness: SignatureInkThickness? = nil,
        textContent: String? = nil,
        textFontSizePoints: CGFloat? = nil,
        textColorRGBA: SignatureInkRGBA? = nil,
        textBold: Bool? = nil,
        textListMode: TextOverlayListMode? = nil
    ) {
        self.id = id
        self.pageItemID = pageItemID
        self.type = type
        self.position = position
        self.size = size
        self.rotation = rotation
        self.opacity = opacity
        self.zIndex = zIndex
        self.imageAssetID = imageAssetID
        self.signatureLibrarySourceID = signatureLibrarySourceID
        self.signatureSourceImageAssetID = signatureSourceImageAssetID
        self.signatureInkColor = signatureInkColor
        self.signatureCustomInkRGBA = signatureCustomInkRGBA
        self.signatureStrokeThickness = signatureStrokeThickness
        self.signatureStrokeWidthPoints = signatureStrokeWidthPoints
        self.signatureBaselineInkColor = signatureBaselineInkColor
        self.signatureBaselineStrokeThickness = signatureBaselineStrokeThickness
        self.textContent = textContent
        self.textFontSizePoints = textFontSizePoints
        self.textColorRGBA = textColorRGBA
        self.textBold = textBold
        self.textListMode = textListMode
    }
}
