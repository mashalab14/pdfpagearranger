import PDFKit
import UIKit
@testable import pdfpagearranger

enum PDFTestFactory {
    enum Fixture: String, CaseIterable {
        case onePage = "OnePage"
        case multiPage = "MultiPage"
        case textOnly = "TextOnly"
        case rotatedPages = "RotatedPages"
        case mixedOrientation = "MixedOrientation"
    }

    static func makeTestImage(
        color: UIColor = .red,
        size: CGSize = CGSize(width: 12, height: 12)
    ) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func url(for fixture: Fixture) throws -> URL {
        switch fixture {
        case .onePage:
            return try writePDF(named: fixture.rawValue, pageCount: 1, labels: ["Single Page"])
        case .multiPage:
            return try writePDF(named: fixture.rawValue, pageCount: 4, labels: ["Page 1", "Page 2", "Page 3", "Page 4"])
        case .textOnly:
            return try writeTextPDF(named: fixture.rawValue, text: "SelectableExportText")
        case .rotatedPages:
            return try writeRotatedPDF(named: fixture.rawValue)
        case .mixedOrientation:
            return try writeMixedOrientationPDF(named: fixture.rawValue)
        }
    }

    static func makeOrientationProbePDF() throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 200, height: 300)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 200, width: 200, height: 100))
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrientationProbe-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    static func fileHash(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    private static func writeRotatedPDF(named name: String) throws -> URL {
        let url = try writePDF(named: name, pageCount: 1, labels: ["Rotated Source"])
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
            throw NSError(domain: "PDFTestFactory", code: 1)
        }
        page.rotation = 90
        guard document.write(to: url) else {
            throw NSError(domain: "PDFTestFactory", code: 2)
        }
        return url
    }

    private static func writeMixedOrientationPDF(named name: String) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).pdf")
        let document = PDFDocument()

        let portrait = try writePDF(named: "tmp-portrait", pageCount: 1, labels: ["Portrait"])
        let landscape = try writePDF(named: "tmp-landscape", pageCount: 1, labels: ["Landscape"])

        if let portraitDoc = PDFDocument(url: portrait), let portraitPage = portraitDoc.page(at: 0)?.copy() as? PDFPage {
            document.insert(portraitPage, at: document.pageCount)
        }
        if let landscapeDoc = PDFDocument(url: landscape), let landscapePage = landscapeDoc.page(at: 0)?.copy() as? PDFPage {
            landscapePage.rotation = 90
            document.insert(landscapePage, at: document.pageCount)
        }

        guard document.write(to: outputURL) else {
            throw NSError(domain: "PDFTestFactory", code: 3)
        }

        try? FileManager.default.removeItem(at: portrait)
        try? FileManager.default.removeItem(at: landscape)
        return outputURL
    }

    private static func write(_ data: Data, named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }
}

// Backward compatibility for existing tests.
enum PDFTestFixtures {
    static func makeTestImage(color: UIColor = .red, size: CGSize = CGSize(width: 12, height: 12)) -> UIImage {
        PDFTestFactory.makeTestImage(color: color, size: size)
    }

    static func makeTextPDF(text: String, fileName: String = UUID().uuidString) throws -> URL {
        try PDFTestFactory.writeTextPDF(named: fileName, text: text)
    }

    static func makeMultiPagePDF(pageCount: Int, labelPrefix: String = "Page") throws -> URL {
        let labels = (1...pageCount).map { "\(labelPrefix) \($0)" }
        return try PDFTestFactory.writePDF(named: "MultiPage", pageCount: pageCount, labels: labels)
    }

    static func makeImageOverlay(
        pageItemID: UUID,
        assetID: UUID = UUID(),
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        size: CGSize = CGSize(width: 0.2, height: 0.2),
        zIndex: Int = 0
    ) -> PageObject {
        OverlayTestFactory.makeImageOverlay(
            pageItemID: pageItemID,
            assetID: assetID,
            position: position,
            size: size,
            zIndex: zIndex
        )
    }
}

extension PDFTestFactory {
    static func writeTextPDF(named name: String, text: String) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            (text as NSString).draw(
                at: CGPoint(x: 72, y: 72),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
        }
        return try write(data, named: name)
    }

    static func writePDF(named name: String, pageCount: Int, labels: [String]) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            for index in 0..<pageCount {
                context.beginPage()
                let label = labels.indices.contains(index) ? labels[index] : "Page \(index + 1)"
                (label as NSString).draw(
                    at: CGPoint(x: 72, y: 72),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
                )
            }
        }
        return try write(data, named: name)
    }
}
