import PDFKit
import XCTest
@testable import pdfpagearranger

final class PDFExportComprehensiveRegressionTests: XCTestCase {
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []

    override func setUp() {
        super.setUp()
        pdfService = PDFService()
    }

    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        pdfService = nil
        super.tearDown()
    }

    func testExportPreservesPageOrderAfterReorder() throws {
        let sourceURL = try PDFTestFactory.url(for: .multiPage)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        var pages = pdfService.makeInitialPages(pageCount: imported.pageCount)
        let moved = pages.remove(at: 3)
        pages.insert(moved, at: 0)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "order-test"
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("Page 4", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 1", at: 1, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 2", at: 2, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 3", at: 3, in: exportURL)
    }

    func testExportPreservesRotation() throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 180

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "rotation-test"
        )
        tempURLs.append(exportURL)

        let exported = try XCTUnwrap(PDFDocument(url: exportURL))
        let exportedPage = try XCTUnwrap(exported.page(at: 0))
        XCTAssertEqual(exportedPage.rotation, 180)
    }

    func testExportIncludesImageOverlays() throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(
            pageItemID: page.id,
            assetID: assetID,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.3, height: 0.3)
        )

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "overlay-test",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage(color: .green)]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(1, in: exportURL)
        let exported = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertNotNil(exported.page(at: 0))
    }

    func testExportPreservesSelectableTextWithOverlays() throws {
        let expectedText = "SelectableExportText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "TextOnly", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "text-overlay-test",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage()]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
    }

    func testExportSourceDoesNotRasterizePages() throws {
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }
}
