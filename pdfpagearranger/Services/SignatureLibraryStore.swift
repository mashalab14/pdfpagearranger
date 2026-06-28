import Foundation
import UIKit

enum SignatureLibraryStoreError: LocalizedError, Equatable {
    case emptyImageData
    case invalidImageData
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .emptyImageData:
            return "Signature image data is empty."
        case .invalidImageData:
            return "Signature image data could not be decoded."
        case .writeFailed:
            return "Could not save the signature to local storage."
        }
    }
}

/// Local on-device library for reusable signature assets.
/// Separate from in-memory PDF page overlay image assets.
final class SignatureLibraryStore {
    static let metadataFileName = "signatures.json"
    static let imagesDirectoryName = "images"
    static let thumbnailsDirectoryName = "thumbnails"

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let metadataURL: URL
    private let imagesDirectory: URL
    private let thumbnailsDirectory: URL

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        metadataURL = rootDirectory.appendingPathComponent(Self.metadataFileName)
        imagesDirectory = rootDirectory.appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
        thumbnailsDirectory = rootDirectory.appendingPathComponent(Self.thumbnailsDirectoryName, isDirectory: true)
    }

    static func defaultRootDirectory(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("SignatureLibrary", isDirectory: true)
    }

    static func makeDefault(fileManager: FileManager = .default) throws -> SignatureLibraryStore {
        SignatureLibraryStore(rootDirectory: try defaultRootDirectory(fileManager: fileManager), fileManager: fileManager)
    }

    @discardableResult
    func saveSignature(
        imageData: Data,
        sourceType: SignatureAssetSourceType,
        displayName: String = SignatureAsset.defaultDisplayName
    ) throws -> SignatureAsset {
        guard !imageData.isEmpty else {
            throw SignatureLibraryStoreError.emptyImageData
        }
        guard UIImage(data: imageData) != nil else {
            throw SignatureLibraryStoreError.invalidImageData
        }

        try ensureDirectoriesExist()

        let assetID = UUID()
        let imageFileName = "\(assetID.uuidString).png"
        let thumbnailFileName = "\(assetID.uuidString).png"
        let now = Date()

        let asset = SignatureAsset(
            id: assetID,
            displayName: displayName,
            createdAt: now,
            updatedAt: now,
            sourceType: sourceType,
            imageFileName: imageFileName,
            thumbnailFileName: thumbnailFileName
        )

        let imageURL = imagesDirectory.appendingPathComponent(imageFileName)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)

        do {
            try imageData.write(to: imageURL, options: .atomic)
            if let thumbnailData = makeThumbnailData(from: imageData) {
                try thumbnailData.write(to: thumbnailURL, options: .atomic)
            }
        } catch {
            try? fileManager.removeItem(at: imageURL)
            try? fileManager.removeItem(at: thumbnailURL)
            throw SignatureLibraryStoreError.writeFailed
        }

        var assets = loadMetadataRecords()
        assets.append(asset)
        try persistMetadataRecords(assets)

        return asset
    }

    func listSignatures() -> [SignatureAsset] {
        loadMetadataRecords()
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
    }

    func getSignature(id: UUID) -> SignatureAsset? {
        loadMetadataRecords().first { $0.id == id }
    }

    func deleteSignature(id: UUID) {
        var assets = loadMetadataRecords()
        guard let index = assets.firstIndex(where: { $0.id == id }) else {
            return
        }

        let asset = assets.remove(at: index)
        try? persistMetadataRecords(assets)
        removeFiles(for: asset)
    }

    func imageURL(for asset: SignatureAsset) -> URL {
        imagesDirectory.appendingPathComponent(asset.imageFileName)
    }

    func thumbnailURL(for asset: SignatureAsset) -> URL? {
        guard let thumbnailFileName = asset.thumbnailFileName else { return nil }
        return thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
    }

    func loadImageData(for asset: SignatureAsset) -> Data? {
        let url = imageURL(for: asset)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func loadImageData(for id: UUID) -> Data? {
        guard let asset = getSignature(id: id) else { return nil }
        return loadImageData(for: asset)
    }

    func loadThumbnailData(for asset: SignatureAsset) -> Data? {
        guard let url = thumbnailURL(for: asset),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    func hasImageFile(for asset: SignatureAsset) -> Bool {
        fileManager.fileExists(atPath: imageURL(for: asset).path)
    }

    // MARK: - Private

    private func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    private func loadMetadataRecords() -> [SignatureAsset] {
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let assets = try? decoder.decode([SignatureAsset].self, from: data) else {
            return []
        }

        return assets
    }

    private func persistMetadataRecords(_ assets: [SignatureAsset]) throws {
        try ensureDirectoriesExist()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(assets)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func removeFiles(for asset: SignatureAsset) {
        try? fileManager.removeItem(at: imageURL(for: asset))
        if let thumbnailURL = thumbnailURL(for: asset) {
            try? fileManager.removeItem(at: thumbnailURL)
        }
    }

    private func makeThumbnailData(from imageData: Data, maxDimension: CGFloat = 120) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }

        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }

        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return thumbnail.pngData()
    }
}
