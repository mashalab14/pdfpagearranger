import Foundation
import PDFKit
import UIKit

actor ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, UIImage>()
    private let maxThumbnailDimension: CGFloat = 240

    init() {
        cache.countLimit = 80
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    func thumbnail(
        for item: PageItem,
        document: PDFDocument,
        overlays: [PageObject],
        overlayImages: [UUID: UIImage],
        revision: Int
    ) async -> UIImage? {
        let cacheKey = "\(item.id.uuidString)-\(item.rotation)-\(revision)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let page = document.page(at: item.originalPageIndex) else {
            return nil
        }

        let image = await renderThumbnail(
            page: page,
            rotation: item.rotation,
            overlays: overlays,
            overlayImages: overlayImages
        )

        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
            cache.setObject(image, forKey: cacheKey, cost: cost)
        }
        return image
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func renderThumbnail(
        page: PDFPage,
        rotation: Int,
        overlays: [PageObject],
        overlayImages: [UUID: UIImage]
    ) async -> UIImage? {
        let maxDimension = maxThumbnailDimension
        return await Task.detached(priority: .utility) {
            guard let baseImage = PDFPreviewRenderer.image(
                from: page,
                rotation: rotation,
                maxDimension: maxDimension,
                maxScale: 1.0
            ) else {
                return nil
            }

            guard !overlays.isEmpty else {
                return baseImage
            }

            return OverlayCompositor.composite(
                baseImage: baseImage,
                objects: overlays,
                images: overlayImages
            )
        }.value
    }
}
