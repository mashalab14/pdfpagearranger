import Foundation
import PDFKit
import UIKit

actor PageRenderService {
    static let shared = PageRenderService()

    func pageImage(
        for item: PageItem,
        document: PDFDocument,
        maxDimension: CGFloat = 2048
    ) async -> UIImage? {
        guard let page = document.page(at: item.originalPageIndex) else {
            return nil
        }

        return await renderPage(page: page, rotation: item.rotation, maxDimension: maxDimension)
    }

    private func renderPage(page: PDFPage, rotation: Int, maxDimension: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            PDFPreviewRenderer.image(
                from: page,
                rotation: rotation,
                maxDimension: maxDimension
            )
        }.value
    }
}
