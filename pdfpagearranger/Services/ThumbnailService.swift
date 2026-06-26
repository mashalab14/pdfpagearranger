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

    func thumbnail(for item: PageItem, document: PDFDocument) async -> UIImage? {
        let cacheKey = "\(item.id.uuidString)-\(item.rotation)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let page = document.page(at: item.originalPageIndex) else {
            return nil
        }

        let image = await renderThumbnail(page: page, rotation: item.rotation)
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
            cache.setObject(image, forKey: cacheKey, cost: cost)
        }
        return image
    }

    func invalidate(for itemID: UUID) {
        // NSCache has no prefix invalidation; thumbnails are keyed by id+rotation.
        // Stale entries expire naturally via count limit.
        _ = itemID
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func renderThumbnail(page: PDFPage, rotation: Int) async -> UIImage? {
        let maxDimension = maxThumbnailDimension
        return await Task.detached(priority: .utility) {
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(
                maxDimension / max(bounds.width, bounds.height),
                1.0
            )
            let thumbnailSize = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: thumbnailSize))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: thumbnailSize.width / 2, y: thumbnailSize.height / 2)
                context.cgContext.rotate(by: CGFloat(rotation) * .pi / 180)
                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.translateBy(x: -bounds.width / 2, y: -bounds.height / 2)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
        }.value
    }
}
