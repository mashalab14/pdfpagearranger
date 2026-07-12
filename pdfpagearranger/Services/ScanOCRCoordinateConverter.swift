import CoreGraphics
import Foundation

enum ScanOCRCoordinateConverter {
    /// Converts a Vision normalized bounding box (bottom-left origin) into a PDF drawing
    /// rectangle using a top-left origin and the final processed image pixel dimensions.
    static func pdfRect(
        fromVisionNormalizedBox box: CGRect,
        pagePixelSize: CGSize
    ) -> CGRect {
        let pageWidth = pagePixelSize.width
        let pageHeight = pagePixelSize.height
        let width = box.width * pageWidth
        let height = box.height * pageHeight
        let x = box.origin.x * pageWidth
        let y = (1.0 - box.origin.y - box.height) * pageHeight
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Converts a PDF drawing rectangle back into Vision normalized coordinates.
    static func visionNormalizedBox(
        fromPDFRect rect: CGRect,
        pagePixelSize: CGSize
    ) -> CGRect {
        guard pagePixelSize.width > 0, pagePixelSize.height > 0 else {
            return .zero
        }

        let pageWidth = pagePixelSize.width
        let pageHeight = pagePixelSize.height
        let normalizedWidth = rect.width / pageWidth
        let normalizedHeight = rect.height / pageHeight
        let normalizedX = rect.origin.x / pageWidth
        let normalizedY = 1.0 - ((rect.origin.y + rect.height) / pageHeight)
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }
}
