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
        revision: Int,
        pageNumberSettings: PageNumberSettings = .default,
        watermarkSettings: WatermarkSettings = .default,
        watermarkImage: UIImage? = nil,
        exportIndex: Int = 0,
        totalPages: Int = 1
    ) async -> UIImage? {
        let cacheKey = "\(item.id.uuidString)-\(item.rotation)-\(revision)-\(pageNumberSettings.thumbnailCacheKeySuffix)-\(watermarkSettings.thumbnailCacheKeySuffix)-\(exportIndex)-\(totalPages)" as NSString
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
            overlayImages: overlayImages,
            pageNumberSettings: pageNumberSettings,
            watermarkSettings: watermarkSettings,
            watermarkImage: watermarkImage,
            exportIndex: exportIndex,
            totalPages: totalPages
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
        overlayImages: [UUID: UIImage],
        pageNumberSettings: PageNumberSettings,
        watermarkSettings: WatermarkSettings,
        watermarkImage: UIImage?,
        exportIndex: Int,
        totalPages: Int
    ) async -> UIImage? {
        let maxDimension = maxThumbnailDimension
        let mediaBox = page.bounds(for: .mediaBox)
        return await Task.detached(priority: .utility) {
            guard var image = PDFPreviewRenderer.image(
                from: page,
                rotation: rotation,
                maxDimension: maxDimension,
                maxScale: 1.0
            ) else {
                return nil
            }

            if watermarkSettings.shouldApply(toExportIndex: exportIndex) {
                image = WatermarkRenderer.compositeOnImage(
                    pageImage: image,
                    pageRotation: rotation,
                    settings: watermarkSettings,
                    mediaBox: mediaBox,
                    watermarkImage: watermarkImage
                )
            }

            if !overlays.isEmpty {
                image = OverlayCompositor.composite(
                    baseImage: image,
                    objects: overlays,
                    images: overlayImages,
                    pageRotation: rotation
                )
            }

            if pageNumberSettings.shouldApply(toExportIndex: exportIndex) {
                let displayNumber = pageNumberSettings.displayNumber(forExportIndex: exportIndex)
                image = PageNumberRenderer.compositeOnImage(
                    baseImage: image,
                    pageRotation: rotation,
                    settings: pageNumberSettings,
                    displayNumber: displayNumber,
                    totalPages: totalPages
                )
            }

            return image
        }.value
    }
}
