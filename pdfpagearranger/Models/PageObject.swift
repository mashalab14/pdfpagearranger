import CoreGraphics
import Foundation

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

    var usesRasterImageAsset: Bool {
        (type == .image || type == .signature) && imageAssetID != nil
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
        imageAssetID: UUID? = nil
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
    }
}
