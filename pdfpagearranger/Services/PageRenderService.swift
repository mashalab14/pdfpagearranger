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
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(
                maxDimension / max(bounds.width, bounds.height),
                4.0
            )
            let imageSize = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: imageSize)
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: imageSize.width / 2, y: imageSize.height / 2)
                context.cgContext.rotate(by: CGFloat(rotation) * .pi / 180)
                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.translateBy(x: -bounds.width / 2, y: -bounds.height / 2)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
        }.value
    }
}
