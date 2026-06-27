import PDFKit
import XCTest
@testable import pdfpagearranger

final class PDFServiceExportRegressionTests: XCTestCase {
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

    func testExportOverlayPagePreservesSelectableText() throws {
        let expectedText = "SelectableExportText"
        let sourceURL = try PDFTestFixtures.makeTextPDF(text: expectedText)
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: imported.pageCount)
        let page = pages[0]
        let assetID = UUID()
        let overlay = PDFTestFixtures.makeImageOverlay(pageItemID: page.id, assetID: assetID)
        let image = PDFTestFixtures.makeTestImage()

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "text-export-test",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: image]
        )
        tempURLs.append(exportURL)

        let exportedDocument = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertEqual(exportedDocument.pageCount, 1)

        let exportedText = exportedDocument.page(at: 0)?.string ?? ""
        XCTAssertTrue(
            exportedText.contains(expectedText),
            "Expected exported overlay page to preserve text. Got: \(exportedText)"
        )
    }

    func testExportPageCountAfterDeleteReorderAndDuplicate() throws {
        let sourceURL = try PDFTestFixtures.makeMultiPagePDF(pageCount: 4)
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: imported.pageCount)

        pages.remove(at: 1)

        let moved = pages.remove(at: 2)
        pages.insert(moved, at: 0)

        let duplicateSource = pages[1]
        let duplicate = PageItem(
            originalPageIndex: duplicateSource.originalPageIndex,
            rotation: duplicateSource.rotation,
            duplicateSourceID: duplicateSource.id
        )
        pages.insert(duplicate, at: 2)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-count-test"
        )
        tempURLs.append(exportURL)

        let exportedDocument = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertEqual(exportedDocument.pageCount, pages.count)
        XCTAssertEqual(exportedDocument.pageCount, 4)
    }

    func testExportWithoutOverlaysUsesDirectPageCopy() throws {
        let sourceURL = try PDFTestFixtures.makeMultiPagePDF(pageCount: 2)
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: imported.pageCount)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "plain-export-test"
        )
        tempURLs.append(exportURL)

        let exportedDocument = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertEqual(exportedDocument.pageCount, 2)
        XCTAssertTrue(exportedDocument.page(at: 0)?.string?.contains("Page 1") == true)
        XCTAssertTrue(exportedDocument.page(at: 1)?.string?.contains("Page 2") == true)
    }
}
