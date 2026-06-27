import XCTest

final class OverlayGeometryEngineSourceRegressionTests: XCTestCase {
    private func source(named fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger")
        switch fileName {
        case "OverlayCompositor.swift":
            return try String(contentsOf: url.appendingPathComponent("Services/OverlayCompositor.swift"), encoding: .utf8)
        case "OverlayPDFExporter.swift":
            return try String(contentsOf: url.appendingPathComponent("Services/OverlayPDFExporter.swift"), encoding: .utf8)
        case "ImageOverlayObjectView.swift":
            return try String(contentsOf: url.appendingPathComponent("Views/ImageOverlayObjectView.swift"), encoding: .utf8)
        case "PDFService.swift":
            return try String(contentsOf: url.appendingPathComponent("Services/PDFService.swift"), encoding: .utf8)
        default:
            XCTFail("Unknown source file \(fileName)")
            return ""
        }
    }

    func testOverlayCompositorUsesOverlayGeometryEngine() throws {
        let compositorSource = try source(named: "OverlayCompositor.swift")
        XCTAssertTrue(compositorSource.contains("OverlayGeometryEngine.thumbnailLayout"))
        XCTAssertTrue(compositorSource.contains("OverlayGeometryEngine.drawUIImage"))
        XCTAssertFalse(compositorSource.contains("geometry.size.width * pageSize.width"))
    }

    func testOverlayPDFExporterUsesOverlayGeometryEngine() throws {
        let exporterSource = try source(named: "OverlayPDFExporter.swift")
        XCTAssertTrue(exporterSource.contains("OverlayGeometryEngine.pdfLayout"))
        XCTAssertTrue(exporterSource.contains("OverlayGeometryEngine.drawPDFImage"))
        XCTAssertFalse(exporterSource.contains("displaySize.width * displaySize.height"))
    }

    func testImageOverlayObjectViewUsesOverlayGeometryEngine() throws {
        let viewSource = try source(named: "ImageOverlayObjectView.swift")
        XCTAssertTrue(viewSource.contains("OverlayGeometryEngine.pageModeLayout"))
        XCTAssertTrue(viewSource.contains("OverlayGeometryEngine.storageGeometry"))
        XCTAssertFalse(viewSource.contains("OverlayPageGeometry"))
    }

    func testExportStillUsesVectorPreservingPipeline() throws {
        let pdfServiceSource = try source(named: "PDFService.swift")
        XCTAssertFalse(pdfServiceSource.contains("PDFPage(image:"))
        XCTAssertTrue(pdfServiceSource.contains("sourcePage.draw(with: .mediaBox, to: context)"))
        XCTAssertTrue(pdfServiceSource.contains("OverlayPDFExporter.drawOverlays"))
    }
}
