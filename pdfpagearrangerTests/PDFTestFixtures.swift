import PDFKit
import UIKit
@testable import pdfpagearranger

enum PDFTestFixtures {
    static func makeTestImage(
        color: UIColor = .red,
        size: CGSize = CGSize(width: 12, height: 12)
    ) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func makeTextPDF(text: String, fileName: String = UUID().uuidString) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18)
            ]
            (text as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: attributes)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")
        try data.write(to: url)
        return url
    }

    static func makeMultiPagePDF(pageCount: Int, labelPrefix: String = "Page") throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            for index in 0..<pageCount {
                context.beginPage()
                let text = "\(labelPrefix) \(index + 1)" as NSString
                text.draw(
                    at: CGPoint(x: 72, y: 72),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
                )
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try data.write(to: url)
        return url
    }

    static func makeImageOverlay(
        pageItemID: UUID,
        assetID: UUID = UUID(),
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        size: CGSize = CGSize(width: 0.2, height: 0.2),
        zIndex: Int = 0
    ) -> PageObject {
        PageObject(
            pageItemID: pageItemID,
            type: .image,
            position: position,
            size: size,
            zIndex: zIndex,
            imageAssetID: assetID
        )
    }
}
