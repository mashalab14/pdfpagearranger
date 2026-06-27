import PDFKit
import UIKit

/// Renders PDF pages for on-screen preview only. Export draws vector page content via PDFPage.draw.
enum PDFPreviewRenderer {
    static func image(
        from page: PDFPage,
        rotation: Int,
        maxDimension: CGFloat,
        maxScale: CGFloat = 4.0
    ) -> UIImage? {
        guard let pageCopy = page.copy() as? PDFPage else {
            return nil
        }

        pageCopy.rotation = rotation

        let bounds = pageCopy.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            return nil
        }

        let scale = min(maxDimension / max(bounds.width, bounds.height), maxScale)
        let size = CGSize(
            width: max(bounds.width * scale, 1),
            height: max(bounds.height * scale, 1)
        )

        return pageCopy.thumbnail(of: size, for: .mediaBox)
    }
}
