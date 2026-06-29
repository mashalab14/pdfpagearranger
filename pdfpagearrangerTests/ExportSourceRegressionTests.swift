import XCTest

final class ExportSourceRegressionTests: XCTestCase {
    func testPDFServiceExportDoesNotUsePDFPageImageInitializer() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Services/PDFService.swift")

        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(
            source.contains("PDFPage(image:"),
            "Overlay export must not rasterize pages via PDFPage(image:)."
        )
        XCTAssertTrue(source.contains("sourcePage.draw(with: .mediaBox, to: context)"))
        XCTAssertTrue(source.contains("OverlayPDFExporter.drawOverlays"))
        XCTAssertTrue(
            source.contains("sourcePage.rotation = 0"),
            "Decorated export must draw source content without baking /Rotate into the content stream."
        )
        XCTAssertTrue(
            source.contains("page.rotation = pageRotation"),
            "Decorated export must apply /Rotate on the output page after composition."
        )
    }
}
