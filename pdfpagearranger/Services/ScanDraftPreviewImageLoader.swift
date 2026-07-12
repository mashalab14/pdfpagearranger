import Foundation
import ImageIO
import UIKit

enum ScanDraftImageLoadPurpose: Sendable, Equatable {
    case mainPreview
    case thumbnail
}

protocol ScanDraftPreviewImageLoading: Sendable {
    func previewReference(for page: ScanDraftPage) -> ScanDraftImageReference
    func thumbnailReference(for page: ScanDraftPage) -> ScanDraftImageReference
    func cacheKey(
        for page: ScanDraftPage,
        reference: ScanDraftImageReference,
        purpose: ScanDraftImageLoadPurpose
    ) -> String
    func loadImage(
        reference: ScanDraftImageReference,
        sessionDirectory: URL,
        maxPixelDimension: CGFloat
    ) async throws -> UIImage
}

/// Loads display-safe scan draft images from file-backed references.
struct ScanDraftPreviewImageLoader: ScanDraftPreviewImageLoading {
    static let mainPreviewMaxPixelDimension: CGFloat = 1_600
    static let thumbnailMaxPixelDimension: CGFloat = 320

    private let storage: ScanDraftSessionStorage
    private let cache: ScanDraftPreviewImageCache

    init(
        storage: ScanDraftSessionStorage = ScanDraftSessionStorage(),
        cache: ScanDraftPreviewImageCache = ScanDraftPreviewImageCache()
    ) {
        self.storage = storage
        self.cache = cache
    }

    func previewReference(for page: ScanDraftPage) -> ScanDraftImageReference {
        if ScanProcessingFingerprint.isProcessedOutputValid(for: page),
           let processedImage = page.processedImage {
            return processedImage
        }
        return page.originalImage
    }

    func thumbnailReference(for page: ScanDraftPage) -> ScanDraftImageReference {
        if page.thumbnailState == .ready, let thumbnailImage = page.thumbnailImage {
            return thumbnailImage
        }
        return page.originalImage
    }

    func cacheKey(
        for page: ScanDraftPage,
        reference: ScanDraftImageReference,
        purpose: ScanDraftImageLoadPurpose
    ) -> String {
        let revision = page.processingFingerprint ?? page.originalImage.relativePath
        return "\(page.id.uuidString)-\(purpose)-\(reference.relativePath)-\(revision)"
    }

    func loadImage(
        reference: ScanDraftImageReference,
        sessionDirectory: URL,
        maxPixelDimension: CGFloat
    ) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            let data = try storage.loadImageData(at: reference, sessionDirectory: sessionDirectory)
            guard let image = Self.downsampledImage(from: data, maxPixelDimension: maxPixelDimension) else {
                throw ScanDraftError.imageCannotBeLoaded
            }
            return image
        }.value
    }

    func cachedImage(for key: String) async -> UIImage? {
        await cache.image(for: key)
    }

    func storeCachedImage(_ image: UIImage, for key: String) async {
        await cache.store(image, for: key)
    }

    static func downsampledImage(from data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        guard !data.isEmpty else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

actor ScanDraftPreviewImageCache {
    private var storage: [String: UIImage] = [:]

    func image(for key: String) -> UIImage? {
        storage[key]
    }

    func store(_ image: UIImage, for key: String) {
        storage[key] = image
    }

    func removeAll() {
        storage.removeAll()
    }
}

enum ScanDraftPreviewLoadGuard {
    static func shouldApplyLoadedImage(
        requestedPageID: UUID,
        currentPageID: UUID,
        isCancelled: Bool
    ) -> Bool {
        !isCancelled && requestedPageID == currentPageID
    }
}
