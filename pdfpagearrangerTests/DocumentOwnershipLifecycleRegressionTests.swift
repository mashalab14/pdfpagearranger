import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class DocumentOwnershipLifecycleRegressionTests: XCTestCase {
    private var root: URL!
    private var store: RecentDocumentsStore!
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OwnershipLifecycle-\(UUID().uuidString)", isDirectory: true)
        store = RecentDocumentsStore(rootDirectory: root)
        viewModel = PDFEditorViewModel(recentDocumentsStore: store)
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        try? FileManager.default.removeItem(at: root)
        viewModel = nil
        store = nil
        try await super.tearDown()
    }

    func testAdoptCompressedPDFFromExternalCreatesNewAppOwnedRecentEntry() async throws {
        let sourceURL = try writeUniquePDF(named: "ExternalSource", pageCount: 2)
        let originalBytes = try Data(contentsOf: sourceURL)

        await viewModel.importPDF(from: sourceURL, ownership: .external)
        XCTAssertEqual(store.loadAvailableDocuments().count, 1)
        XCTAssertEqual(store.loadAvailableDocuments().first?.ownership, .external)
        let externalKey = try XCTUnwrap({
            if case .external(let key) = viewModel.activeDocumentOrigin { return key }
            return nil
        }())

        let compressedURL = try writeUniquePDF(named: "CompressedDerivative", pageCount: 2)
        await viewModel.adoptCompressedPDF(from: compressedURL)

        let entries = store.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.filter { $0.ownership == .appOwned }.count, 1)
        XCTAssertEqual(entries.filter { $0.ownership == .external }.count, 1)
        XCTAssertEqual(entries.first?.ownership, .appOwned)
        if case .appOwned = viewModel.activeDocumentOrigin {
            // expected
        } else {
            XCTFail("Expected app-owned origin after adopt")
        }
        XCTAssertEqual(try Data(contentsOf: sourceURL), originalBytes)

        let externalStill = try XCTUnwrap(entries.first(where: { $0.ownership == .external }))
        XCTAssertEqual(externalStill.identityKey, externalKey)
    }

    func testAdoptCompressedPDFFromAppOwnedReplacesSameAuthoritativeFile() async throws {
        await viewModel.createBlankDocument()
        let ownedID = try XCTUnwrap({
            if case .appOwned(let id) = viewModel.activeDocumentOrigin { return id }
            return nil
        }())
        let ownedURL = store.appOwnedFileURL(id: ownedID)
        let beforeBytes = try Data(contentsOf: ownedURL)

        let compressedURL = try writeUniquePDF(named: "AppOwnedCompressed", pageCount: 1)
        let compressedBytes = try Data(contentsOf: compressedURL)
        await viewModel.adoptCompressedPDF(from: compressedURL)

        XCTAssertEqual(store.loadAvailableDocuments().count, 1)
        let afterID = try XCTUnwrap({
            if case .appOwned(let id) = viewModel.activeDocumentOrigin { return id }
            return nil
        }())
        XCTAssertEqual(afterID, ownedID)
        let afterBytes = try Data(contentsOf: store.appOwnedFileURL(id: ownedID))
        XCTAssertEqual(afterBytes, compressedBytes)
        XCTAssertNotEqual(afterBytes, beforeBytes)
        XCTAssertTrue(viewModel.hasDocument)
    }

    func testAppOwnedExportWritebackPersistsEditedPageCount() async throws {
        await viewModel.createBlankDocument()
        let ownedID = try XCTUnwrap({
            if case .appOwned(let id) = viewModel.activeDocumentOrigin { return id }
            return nil
        }())
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.duplicatePage(id: page.id)
        XCTAssertEqual(viewModel.pageCount, 2)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)
        let ownedURL = store.appOwnedFileURL(id: ownedID)
        let ownedDocument = try XCTUnwrap(PDFDocument(url: ownedURL))
        XCTAssertEqual(ownedDocument.pageCount, 2)
        XCTAssertEqual(try Data(contentsOf: ownedURL), try Data(contentsOf: exportURL))

        await viewModel.closeSession()
        let record = try XCTUnwrap(store.loadAvailableDocuments().first)
        XCTAssertEqual(record.id, ownedID)
        await viewModel.openRecentDocument(record)

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 2)
        if case .appOwned(let id) = viewModel.activeDocumentOrigin {
            XCTAssertEqual(id, ownedID)
        } else {
            XCTFail("Expected app-owned origin after reopen")
        }
    }

    func testPrepareCompressionWritebackUpdatesAppOwnedAuthoritativeFile() async throws {
        await viewModel.createBlankDocument()
        let ownedID = try XCTUnwrap({
            if case .appOwned(let id) = viewModel.activeDocumentOrigin { return id }
            return nil
        }())
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.duplicatePage(id: page.id)

        let prepared = try await viewModel.prepareCompressionInput()
        tempURLs.append(prepared.exportURL)

        let ownedURL = store.appOwnedFileURL(id: ownedID)
        let ownedDocument = try XCTUnwrap(PDFDocument(url: ownedURL))
        XCTAssertEqual(ownedDocument.pageCount, 2)
        XCTAssertEqual(try Data(contentsOf: ownedURL), try Data(contentsOf: prepared.exportURL))
    }

    func testExternalExportDoesNotWriteBackToSourceOrCreateAppOwnedCopy() async throws {
        let sourceURL = try writeUniquePDF(named: "ExternalNoWriteback", pageCount: 1)
        let originalBytes = try Data(contentsOf: sourceURL)

        await viewModel.importPDF(from: sourceURL, ownership: .external)
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.duplicatePage(id: page.id)
        XCTAssertEqual(viewModel.pageCount, 2)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)

        XCTAssertEqual(try Data(contentsOf: sourceURL), originalBytes)
        XCTAssertEqual(store.loadAvailableDocuments().count, 1)
        XCTAssertEqual(store.loadAvailableDocuments().first?.ownership, .external)
        let appOwnedPDFs = (try? FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent(RecentDocumentsStore.appOwnedDirectoryName),
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(appOwnedPDFs.filter { $0.pathExtension == "pdf" }.isEmpty)
    }

    func testExportSucceedsWhenAppOwnedWritebackTargetMissing() async throws {
        await viewModel.createBlankDocument()
        let ownedID = try XCTUnwrap({
            if case .appOwned(let id) = viewModel.activeDocumentOrigin { return id }
            return nil
        }())
        try store.removeDocument(id: ownedID)
        XCTAssertTrue(store.loadAvailableDocuments().isEmpty)

        // Origin still points at removed id; write-back fails silently via try?
        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(viewModel.hasDocument)
    }

    func testAppRootWiresOpenURLToIncomingDocumentHandler() throws {
        let appSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/pdfpagearrangerApp.swift")
        )
        XCTAssertTrue(appSource.contains(".onOpenURL"))
        XCTAssertTrue(appSource.contains("handleIncomingDocumentURL(url)"))
    }

    // MARK: - Fixtures

    private func writeUniquePDF(named name: String, pageCount: Int) throws -> URL {
        let labels = (0..<pageCount).map { "\(name)-\($0)-\(UUID().uuidString)" }
        let url = try PDFTestFactory.writePDF(named: name, pageCount: pageCount, labels: labels)
        tempURLs.append(url)
        return url
    }
}
