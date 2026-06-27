import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFImportRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        viewModel = nil
        try await super.tearDown()
    }

    func testImportMultiPagePDFOpensDocumentWithCorrectPageCount() async throws {
        let sourceURL = try PDFTestFactory.url(for: .multiPage)
        tempURLs.append(sourceURL)

        await viewModel.importPDF(from: sourceURL)

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 4)
        XCTAssertEqual(viewModel.pages.map(\.originalPageIndex), [0, 1, 2, 3])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testImportOnePagePDF() async throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)

        await viewModel.importPDF(from: sourceURL)

        XCTAssertEqual(viewModel.pageCount, 1)
    }

    func testOriginalImportedPDFRemainsUntouchedAfterImportAndExport() async throws {
        let sourceURL = try PDFTestFactory.url(for: .textOnly)
        tempURLs.append(sourceURL)
        let originalData = try Data(contentsOf: sourceURL)

        await viewModel.importPDF(from: sourceURL)
        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)

        try ExportAssertions.assertOriginalPDFUnchanged(originalData: originalData, currentURL: sourceURL)
        try ExportAssertions.assertPageContainsText("SelectableExportText", at: 0, in: exportURL)
    }

    func testImportCopiesToLocalStorageWithoutMutatingSource() async throws {
        let pdfService = PDFService()
        let sourceURL = try PDFTestFactory.url(for: .multiPage)
        tempURLs.append(sourceURL)
        let originalData = try Data(contentsOf: sourceURL)

        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        XCTAssertNotEqual(imported.localURL, sourceURL)
        XCTAssertEqual(imported.pageCount, 4)
        try ExportAssertions.assertOriginalPDFUnchanged(originalData: originalData, currentURL: sourceURL)
    }

    func testAllProgrammaticFixturesAreReadable() throws {
        for fixture in PDFTestFactory.Fixture.allCases {
            let url = try PDFTestFactory.url(for: fixture)
            tempURLs.append(url)
            let document = try XCTUnwrap(PDFDocument(url: url))
            XCTAssertGreaterThan(document.pageCount, 0, "Fixture \(fixture.rawValue) should have pages")
        }
    }
}
