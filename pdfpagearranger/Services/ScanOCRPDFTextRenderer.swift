import Foundation
import UIKit

enum ScanOCRPDFTextRenderer {
    static func drawInvisibleText(
        for ocrPage: OCRPage,
        in context: UIGraphicsPDFRendererContext,
        pagePixelSize: CGSize
    ) {
        guard ocrPage.status == .succeeded else { return }

        let cgContext = context.cgContext
        cgContext.saveGState()
        defer { cgContext.restoreGState() }

        cgContext.setTextDrawingMode(.invisible)

        for line in ocrPage.lines {
            let rect = ScanOCRCoordinateConverter.pdfRect(
                fromVisionNormalizedBox: line.normalizedBoundingBox.cgRect,
                pagePixelSize: pagePixelSize
            )
            drawLine(line.text, in: rect, context: context)
        }
    }

    private static func drawLine(
        _ text: String,
        in rect: CGRect,
        context: UIGraphicsPDFRendererContext
    ) {
        guard !text.isEmpty, rect.width > 0, rect.height > 0 else { return }

        let fontSize = max(min(rect.height * 0.85, rect.height), 4)
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]

        let measuredWidth = (text as NSString).size(withAttributes: attributes).width
        let cgContext = context.cgContext

        cgContext.saveGState()
        defer { cgContext.restoreGState() }

        if measuredWidth > rect.width, measuredWidth > 0 {
            let scale = rect.width / measuredWidth
            cgContext.translateBy(x: rect.minX, y: rect.minY + rect.height)
            cgContext.scaleBy(x: scale, y: 1)
            (text as NSString).draw(
                at: CGPoint(x: 0, y: -fontSize),
                withAttributes: attributes
            )
        } else {
            let y = rect.minY + max((rect.height - fontSize) / 2, 0)
            (text as NSString).draw(
                at: CGPoint(x: rect.minX, y: y),
                withAttributes: attributes
            )
        }
    }
}
