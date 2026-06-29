import Foundation
import PDFKit
import UIKit

actor PageRenderService {
    static let shared = PageRenderService()

    func pageImage(
        for item: PageItem,
        document: PDFDocument,
        maxDimension: CGFloat = 2048,
        pageNumberSettings: PageNumberSettings = .default,
        watermarkSettings: WatermarkSettings = .default,
        exportIndex: Int = 0,
        totalPages: Int = 1
    ) async -> UIImage? {
        guard let page = document.page(at: item.originalPageIndex) else {
            return nil
        }

        return await renderPage(
            page: page,
            rotation: item.rotation,
            maxDimension: maxDimension,
            pageNumberSettings: pageNumberSettings,
            watermarkSettings: watermarkSettings,
            exportIndex: exportIndex,
            totalPages: totalPages
        )
    }

    private func renderPage(
        page: PDFPage,
        rotation: Int,
        maxDimension: CGFloat,
        pageNumberSettings: PageNumberSettings,
        watermarkSettings: WatermarkSettings,
        exportIndex: Int,
        totalPages: Int
    ) async -> UIImage? {
        let mediaBox = page.bounds(for: .mediaBox)
        return await Task.detached(priority: .userInitiated) {
            guard var image = PDFPreviewRenderer.image(
                from: page,
                rotation: rotation,
                maxDimension: maxDimension
            ) else {
                return nil
            }

            if watermarkSettings.shouldApply(toExportIndex: exportIndex) {
                image = WatermarkRenderer.compositeOnImage(
                    baseImage: image,
                    pageRotation: rotation,
                    settings: watermarkSettings,
                    mediaBoxWidth: mediaBox.width
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
