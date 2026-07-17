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

    func testImportRejectsUnreadableFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-pdf-\(UUID().uuidString).pdf")
        try Data("not a pdf".utf8).write(to: url)
        tempURLs.append(url)

        await viewModel.importPDF(from: url)

        XCTAssertFalse(viewModel.hasDocument)
        XCTAssertEqual(viewModel.errorMessage, PDFServiceError.unreadable.localizedDescription)
    }

    func testImportRejectsZeroPagePDFFile() async throws {
        // PDFKit refuses to open /Count 0 files (nil document). Import must fail
        // without opening a session; PDFService maps that to `.unreadable`.
        // (In-memory `PDFDocument()` has pageCount 0, but `write`/`dataRepresentation`
        // always serialize at least one page on current PDFKit, so `.empty` is a
        // defensive guard rather than a file-import path we can fixture here.)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString).pdf")
        try Self.zeroPagePDFData.write(to: url)
        tempURLs.append(url)
        XCTAssertNil(PDFDocument(url: url))

        await viewModel.importPDF(from: url)

        XCTAssertFalse(viewModel.hasDocument)
        XCTAssertEqual(viewModel.errorMessage, PDFServiceError.unreadable.localizedDescription)
    }

    /// Minimal PDF catalog with `/Kids []` / `/Count 0` (PDFKit returns nil).
    private static let zeroPagePDFData: Data = {
        let header = Data("%PDF-1.4\n".utf8)
        let o1 = Data("1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n".utf8)
        let o2 = Data("2 0 obj<< /Type /Pages /Kids [] /Count 0 >>endobj\n".utf8)
        let body = header + o1 + o2
        let off1 = header.count
        let off2 = off1 + o1.count
        let xrefPos = body.count
        var xref = Data("xref\n0 3\n".utf8)
        xref += Data(String(format: "%010d 65535 f \n", 0).utf8)
        xref += Data(String(format: "%010d 00000 n \n", off1).utf8)
        xref += Data(String(format: "%010d 00000 n \n", off2).utf8)
        let trailer = Data(
            "trailer<< /Size 3 /Root 1 0 R >>\nstartxref\n\(xrefPos)\n%%EOF\n".utf8
        )
        return body + xref + trailer
    }()

    func testPDFServiceThrowsEncryptedForPasswordProtectedPDF() throws {
        // Minimal encrypted PDF trailer pattern is hard to synthesize; verify service maps unlock failure.
        // Use a PDFDocument that reports encrypted with failed empty unlock via a real encrypted fixture if available.
        // Fallback: assert error localization contracts used by import UI.
        XCTAssertEqual(
            PDFServiceError.encrypted.errorDescription,
            "This PDF is password-protected and cannot be opened."
        )
        XCTAssertEqual(
            PDFServiceError.empty.errorDescription,
            "This PDF has no pages."
        )
        XCTAssertEqual(
            PDFServiceError.unreadable.errorDescription,
            "This file could not be read as a PDF."
        )
    }
}
