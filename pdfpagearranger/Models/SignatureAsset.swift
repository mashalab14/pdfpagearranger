import Foundation

enum SignatureAssetSourceType: String, Codable, CaseIterable, Equatable {
    case drawn
    case photo
    case importedImage
}

struct SignatureAsset: Identifiable, Equatable, Codable {
    static let defaultDisplayName = "Signature"

    let id: UUID
    var displayName: String
    let createdAt: Date
    var updatedAt: Date
    let sourceType: SignatureAssetSourceType
    /// File name relative to the store's images directory.
    let imageFileName: String
    /// File name relative to the store's thumbnails directory, when available.
    let thumbnailFileName: String?
    /// Stroke thickness used when the signature was drawn, when available.
    let strokeThickness: SignatureInkThickness?

    init(
        id: UUID = UUID(),
        displayName: String = SignatureAsset.defaultDisplayName,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceType: SignatureAssetSourceType,
        imageFileName: String,
        thumbnailFileName: String? = nil,
        strokeThickness: SignatureInkThickness? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceType = sourceType
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.strokeThickness = strokeThickness
    }
}
