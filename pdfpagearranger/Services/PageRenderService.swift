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
            exportIndex: exportIndex,
            totalPages: totalPages
        )
    }

    private func renderPage(
        page: PDFPage,
        rotation: Int,
        maxDimension: CGFloat,
        pageNumberSettings: PageNumberSettings,
        exportIndex: Int,
        totalPages: Int
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard var image = PDFPreviewRenderer.image(
                from: page,
                rotation: rotation,
                maxDimension: maxDimension
            ) else {
                return nil
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
