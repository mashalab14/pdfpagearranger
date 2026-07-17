import XCTest
@testable import pdfpagearranger
import PDFKit

@MainActor
final class RecentDocumentsStoreRegressionTests: XCTestCase {
    private var store: RecentDocumentsStore!
    private var root: URL!

    override func setUp() async throws {
        try await super.setUp()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentDocumentsTests-\(UUID().uuidString)", isDirectory: true)
        store = RecentDocumentsStore(rootDirectory: root)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        try await super.tearDown()
    }

    func testRecordOrdersMostRecentFirstAndDeduplicatesByFingerprint() throws {
        let first = try writeTempPDF(named: "Alpha", pageCount: 1)
        let second = try writeTempPDF(named: "Beta", pageCount: 2)

        _ = try store.recordOpenedDocument(sourceFileURL: first, displayName: "Alpha", pageCount: 1)
        _ = try store.recordOpenedDocument(sourceFileURL: second, displayName: "Beta", pageCount: 2)
        _ = try store.recordOpenedDocument(sourceFileURL: first, displayName: "Alpha", pageCount: 1)

        let entries = store.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].displayName, "Alpha")
        XCTAssertEqual(entries[1].displayName, "Beta")
    }

    func testHomePreviewLimitsToFive() throws {
        for index in 0..<7 {
            let url = try writeTempPDF(named: "Doc\(index)", pageCount: 1)
            _ = try store.recordOpenedDocument(sourceFileURL: url, displayName: "Doc\(index)", pageCount: 1)
        }

        XCTAssertEqual(store.homePreviewDocuments().count, 5)
        XCTAssertEqual(store.loadAvailableDocuments().count, 7)
    }

    func testMissingFileIsPruned() throws {
        let url = try writeTempPDF(named: "Gone", pageCount: 1)
        let record = try store.recordOpenedDocument(sourceFileURL: url, displayName: "Gone", pageCount: 1)
        try FileManager.default.removeItem(at: store.fileURL(for: record))

        XCTAssertTrue(store.loadAvailableDocuments().isEmpty)
    }

    func testPersistenceAcrossStoreReload() throws {
        let url = try writeTempPDF(named: "Persist", pageCount: 1)
        _ = try store.recordOpenedDocument(sourceFileURL: url, displayName: "Persist", pageCount: 1)

        let reloaded = RecentDocumentsStore(rootDirectory: root)
        let entries = reloaded.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].displayName, "Persist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: reloaded.fileURL(for: entries[0]).path))
    }

    func testImportPDFRecordsRecentDocument() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let url = try writeTempPDF(named: "Imported", pageCount: 1)

        await viewModel.importPDF(from: url)

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(isolated.loadAvailableDocuments().count, 1)
        XCTAssertEqual(isolated.loadAvailableDocuments().first?.displayName, "Imported")
    }

    func testCreateBlankDocumentOpensEditorAndRecordsRecent() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)

        await viewModel.createBlankDocument()

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 1)
        XCTAssertEqual(viewModel.documentName, "Untitled")
        XCTAssertEqual(isolated.loadAvailableDocuments().count, 1)
    }

    func testOpenRecentDocumentLoadsEditor() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let url = try writeTempPDF(named: "Reopen", pageCount: 2)
        await viewModel.importPDF(from: url)
        await viewModel.closeSession()
        XCTAssertFalse(viewModel.hasDocument)

        let record = try XCTUnwrap(isolated.loadAvailableDocuments().first)
        await viewModel.openRecentDocument(record)

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 2)
        XCTAssertEqual(viewModel.documentName, "Reopen")
    }

    func testOpenMissingRecentDocumentCleansUp() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let url = try writeTempPDF(named: "Missing", pageCount: 1)
        let record = try isolated.recordOpenedDocument(sourceFileURL: url, displayName: "Missing", pageCount: 1)
        try FileManager.default.removeItem(at: isolated.fileURL(for: record))

        await viewModel.openRecentDocument(record)

        XCTAssertFalse(viewModel.hasDocument)
        XCTAssertTrue(isolated.loadAvailableDocuments().isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    private func writeTempPDF(named name: String, pageCount: Int) throws -> URL {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let page = PDFPage()
            // Embed unique text so fingerprints differ across fixtures.
            let annotation = PDFAnnotation(
                bounds: CGRect(x: 40, y: 700, width: 400, height: 40),
                forType: .freeText,
                withProperties: nil
            )
            annotation.contents = "\(name)-\(index)-\(UUID().uuidString)"
            page.addAnnotation(annotation)
            document.insert(page, at: document.pageCount)
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentDocFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name).appendingPathExtension("pdf")
        guard document.write(to: url) else {
            throw NSError(domain: "RecentDocumentsTests", code: 1)
        }
        return url
    }
}