import PDFKit
import XCTest
@testable import pdfpagearranger

final class PageNumberExportRegressionTests: XCTestCase {
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

    func testPageNumberSettingsDefaultCorrectly() {
        let settings = PageNumberSettings.default

        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.position, .bottomCenter)
        XCTAssertEqual(settings.format, .numberOnly)
        XCTAssertEqual(settings.startNumber, 1)
        XCTAssertTrue(settings.appliesToAllPages)
        XCTAssertEqual(settings.rangeStart, 1)
        XCTAssertEqual(settings.rangeEnd, 1)
        XCTAssertEqual(settings.fontSize, 12)
        XCTAssertEqual(settings.opacity, 1)
    }

    func testPageNumbersApplyToAllPages() throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "page-numbers-all",
            pageCount: 3,
            labels: ["DocA", "DocB", "DocC"]
        )
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 3)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-all",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("Page 1", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 2", at: 1, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 3", at: 2, in: exportURL)
    }

    func testPageNumbersApplyOnlyToSelectedRange() throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "page-numbers-range",
            pageCount: 5,
            labels: ["DocA", "DocB", "DocC", "DocD", "DocE"]
        )
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 5)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.appliesToAllPages = false
        settings.rangeStart = 2
        settings.rangeEnd = 4
        settings.format = .pageNumber

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-range",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        let document = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertFalse(document.page(at: 0)?.string?.contains("Page 1") == true)
        try ExportAssertions.assertPageContainsText("Page 1", at: 1, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 2", at: 2, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 3", at: 3, in: exportURL)
        XCTAssertFalse(document.page(at: 4)?.string?.contains("Page 4") == true)
    }

    func testStartNumberWorks() throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "page-numbers-start",
            pageCount: 2,
            labels: ["DocA", "DocB"]
        )
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 2)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.startNumber = 7
        settings.format = .numberOnly

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-start",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        let firstPageText = try XCTUnwrap(PDFDocument(url: exportURL)?.page(at: 0)?.string)
        let secondPageText = try XCTUnwrap(PDFDocument(url: exportURL)?.page(at: 1)?.string)
        XCTAssertTrue(firstPageText.contains("7"))
        XCTAssertTrue(secondPageText.contains("8"))
    }

    func testEachFormatRendersCorrectText() {
        XCTAssertEqual(PageNumberFormat.numberOnly.formattedText(number: 4, totalPages: 10), "4")
        XCTAssertEqual(PageNumberFormat.pageNumber.formattedText(number: 4, totalPages: 10), "Page 4")
        XCTAssertEqual(
            PageNumberFormat.pageNumberOfTotal.formattedText(number: 4, totalPages: 10),
            "Page 4 of 10"
        )
    }

    func testEachPositionMapsToCorrectPDFCoordinates() {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        let bottomCenter = PageNumberRenderer.pdfAnchor(
            position: .bottomCenter,
            mediaBox: mediaBox,
            pageRotation: 0
        )
        XCTAssertEqual(bottomCenter.point.x, 306, accuracy: 1)
        XCTAssertLessThan(bottomCenter.point.y, 80)
        XCTAssertEqual(bottomCenter.alignment, .center)

        let topCenter = PageNumberRenderer.pdfAnchor(
            position: .topCenter,
            mediaBox: mediaBox,
            pageRotation: 0
        )
        XCTAssertEqual(topCenter.point.x, 306, accuracy: 1)
        XCTAssertGreaterThan(topCenter.point.y, 700)
        XCTAssertEqual(topCenter.alignment, .center)

        let bottomRight = PageNumberRenderer.pdfAnchor(
            position: .bottomRight,
            mediaBox: mediaBox,
            pageRotation: 0
        )
        XCTAssertGreaterThan(bottomRight.point.x, 550)
        XCTAssertLessThan(bottomRight.point.y, 80)
        XCTAssertEqual(bottomRight.alignment, .right)

        let topLeft = PageNumberRenderer.pdfAnchor(
            position: .topLeft,
            mediaBox: mediaBox,
            pageRotation: 0
        )
        XCTAssertLessThan(topLeft.point.x, 80)
        XCTAssertGreaterThan(topLeft.point.y, 700)
        XCTAssertEqual(topLeft.alignment, .left)
    }

    func testExportIncludesPageNumbers() throws {
        let sourceURL = try PDFTestFixtures.makeTextPDF(text: "ExportIncludesNumbers")
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumberOfTotal

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-export",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("Page 1 of 1", at: 0, in: exportURL)
    }

    func testExportPreservesSearchableOriginalPDFText() throws {
        let expectedText = "SelectableExportText"
        let sourceURL = try PDFTestFixtures.makeTextPDF(text: expectedText)
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-text",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 1", at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testPageCountAndOrderRemainUnchangedWithPageNumbers() throws {
        let sourceURL = try PDFTestFixtures.makeMultiPagePDF(pageCount: 4)
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: imported.pageCount)
        let moved = pages.remove(at: 2)
        pages.insert(moved, at: 0)

        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-order",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(4, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 3", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 1", at: 1, in: exportURL)
    }

    func testRotatedPagesHandlePageNumbersCorrectly() throws {
        let sourceURL = try PDFTestFixtures.makeTextPDF(text: "RotatedPageNumber")
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90

        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "page-numbers-rotated",
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("Page 1", at: 0, in: exportURL)

        let exportedPage = try XCTUnwrap(PDFDocument(url: exportURL)?.page(at: 0))
        let mediaBox = exportedPage.bounds(for: .mediaBox)
        let anchor = PageNumberRenderer.pdfAnchor(
            position: .bottomCenter,
            mediaBox: mediaBox,
            pageRotation: 90
        )
        XCTAssertLessThan(anchor.point.y, mediaBox.midY)
    }

    func testExistingOverlayExportStillPassesWithPageNumbers() throws {
        let expectedText = "OverlayWithPageNumbers"
        let sourceURL = try PDFTestFixtures.makeTextPDF(text: expectedText)
        tempURLs.append(sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = PDFTestFixtures.makeImageOverlay(pageItemID: page.id, assetID: assetID)

        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "overlay-page-numbers",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFixtures.makeTestImage()],
            pageNumberSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("Page 1", at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    @MainActor
    func testApplyingPageNumbersIsUndoable() async throws {
        let sourceURL = try PDFTestFixtures.makeTextPDF(text: "UndoPageNumbers")
        tempURLs.append(sourceURL)

        let viewModel = PDFEditorViewModel()
        await viewModel.importPDF(from: sourceURL)

        var settings = PageNumberSettings.default
        settings.format = .pageNumber
        viewModel.applyPageNumbers(settings)

        XCTAssertTrue(viewModel.pageNumberSettings.isEnabled)
        XCTAssertEqual(viewModel.pageNumberSettings.format, .pageNumber)

        viewModel.undo()

        XCTAssertFalse(viewModel.pageNumberSettings.isEnabled)
        XCTAssertEqual(viewModel.pageNumberSettings, .default)
    }
}
