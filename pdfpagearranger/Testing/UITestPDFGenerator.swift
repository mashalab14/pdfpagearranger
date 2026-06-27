import UIKit

enum UITestPDFGenerator {
    static func writeMultiPagePDF(pageCount: Int) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            for index in 0..<pageCount {
                context.beginPage()
                let label = "Page \(index + 1)" as NSString
                label.draw(
                    at: CGPoint(x: 72, y: 72),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
                )
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UITest-AutoImport-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }
}
