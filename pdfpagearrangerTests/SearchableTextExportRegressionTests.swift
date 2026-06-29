import PDFKit
import XCTest
@testable import pdfpagearranger

/// Permanent regression coverage for searchable/selectable original PDF text across export paths.
final class SearchableTextExportRegressionTests: XCTestCase {
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

    private func exportAndAssertText(
        _ expectedText: String,
        pages: [PageItem],
        sourceDocument: PDFDocument,
        overlaysByPage: [UUID: [PageObject]] = [:],
        imageAssets: [UUID: UIImage] = [:],
        pageNumberSettings: PageNumberSettings = .default,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: sourceDocument,
            outputName: "searchable-audit",
            overlaysByPage: overlaysByPage,
            imageAssets: imageAssets,
            pageNumberSettings: pageNumberSettings
        )
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL, file: file, line: line)
    }

    func testPlainExportPreservesSearchableText() throws {
        let expectedText = "SelectableExportText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "plain", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        try exportAndAssertText(expectedText, pages: pages, sourceDocument: imported.document)
    }

    func testRotatedExportWithoutDecorationsPreservesSearchableText() throws {
        let expectedText = "RotatedPlainText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-plain", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        try exportAndAssertText(expectedText, pages: pages, sourceDocument: imported.document)
    }

    func testPageNumbersOnlyPreservesSearchableText() throws {
        let expectedText = "PageNumbersOnlyText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "pn-only", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            pageNumberSettings: settings
        )
    }

    func testRotatedPageNumbersPreserveSearchableText() throws {
        let expectedText = "RotatedPageNumbersText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-pn", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            pageNumberSettings: settings
        )
    }

    func testImageOverlayPreservesSearchableText() throws {
        let expectedText = "OverlayImageText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "overlay-img", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage()]
        )
    }

    func testSignatureOverlayPreservesSearchableText() throws {
        let expectedText = "SignatureOverlayText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "signature-overlay", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeSignatureOverlay(pageItemID: page.id, assetID: assetID)
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage(color: .blue)]
        )
    }

    func testRotatedSignatureOverlayPreservesSearchableText() throws {
        let expectedText = "RotatedSignatureText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-signature", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeSignatureOverlay(pageItemID: page.id, assetID: assetID)
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage(color: .blue)]
        )
    }

    func testRotatedImageOverlayPreservesSearchableText() throws {
        let expectedText = "RotatedOverlayImageText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-overlay-img", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage()]
        )
    }

    func testOverlaysAndPageNumbersPreserveSearchableText() throws {
        let expectedText = "CombinedDecorationsText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "combined", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage()],
            pageNumberSettings: settings
        )
    }

    func testRotatedOverlaysAndPageNumbersPreserveSearchableText() throws {
        let expectedText = "RotatedCombinedText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-combined", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.format = .pageNumber
        try exportAndAssertText(
            expectedText,
            pages: pages,
            sourceDocument: imported.document,
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage()],
            pageNumberSettings: settings
        )
    }
}
