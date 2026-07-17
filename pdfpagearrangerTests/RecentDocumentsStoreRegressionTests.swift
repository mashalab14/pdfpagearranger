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

    func testRecordOrdersMostRecentFirstAndDeduplicatesByIdentity() throws {
        let first = try writeTempPDF(named: "Alpha", pageCount: 1, uniqueContent: true)
        let second = try writeTempPDF(named: "Beta", pageCount: 2, uniqueContent: true)

        _ = try store.recordActiveDocument(
            sourceURL: first,
            displayName: "Alpha",
            pageCount: 1,
            ownership: .external
        )
        _ = try store.recordActiveDocument(
            sourceURL: second,
            displayName: "Beta",
            pageCount: 2,
            ownership: .external
        )
        _ = try store.recordActiveDocument(
            sourceURL: first,
            displayName: "Alpha",
            pageCount: 1,
            ownership: .external
        )

        let entries = store.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].displayName, "Alpha")
        XCTAssertEqual(entries[1].displayName, "Beta")
        XCTAssertEqual(entries[0].ownership, .external)
        XCTAssertNil(entries[0].relativeFilePath)
        XCTAssertNotNil(entries[0].bookmarkData)
    }

    func testIdenticalContentAtDifferentPathsRemainsSeparateDocuments() throws {
        let bytes = try makePDFData(named: "SameBytes", pageCount: 1)
        let first = try writePDFData(bytes, named: "CopyA")
        let second = try writePDFData(bytes, named: "CopyB")

        _ = try store.recordActiveDocument(
            sourceURL: first,
            displayName: "CopyA",
            pageCount: 1,
            ownership: .external
        )
        _ = try store.recordActiveDocument(
            sourceURL: second,
            displayName: "CopyB",
            pageCount: 1,
            ownership: .external
        )

        let entries = store.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 2)
        XCTAssertNotEqual(entries[0].identityKey, entries[1].identityKey)
    }

    func testExternalRecordDoesNotCopyPDFIntoStore() throws {
        let url = try writeTempPDF(named: "External", pageCount: 1, uniqueContent: true)
        let record = try store.recordActiveDocument(
            sourceURL: url,
            displayName: "External",
            pageCount: 1,
            ownership: .external
        )

        let legacyFiles = root.appendingPathComponent(RecentDocumentsStore.legacyFilesDirectoryName)
        let appOwned = root.appendingPathComponent(RecentDocumentsStore.appOwnedDirectoryName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFiles.path))
        let ownedPDFs = (try? FileManager.default.contentsOfDirectory(atPath: appOwned.path)) ?? []
        XCTAssertTrue(ownedPDFs.filter { $0.hasSuffix(".pdf") }.isEmpty)
        XCTAssertNil(record.relativeFilePath)
    }

    func testHomePreviewLimitsToFive() throws {
        for index in 0..<7 {
            let url = try writeTempPDF(named: "Doc\(index)", pageCount: 1, uniqueContent: true)
            _ = try store.recordActiveDocument(
                sourceURL: url,
                displayName: "Doc\(index)",
                pageCount: 1,
                ownership: .external
            )
        }

        XCTAssertEqual(store.homePreviewDocuments().count, 5)
        XCTAssertEqual(store.loadAvailableDocuments().count, 7)
    }

    func testMissingExternalDocumentIsPruned() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentPrune-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Gone.pdf")
        try makePDFData(named: "Gone", pageCount: 1).write(to: url)

        _ = try store.recordActiveDocument(
            sourceURL: url,
            displayName: "Gone",
            pageCount: 1,
            ownership: .external
        )
        try FileManager.default.removeItem(at: url)

        XCTAssertTrue(store.loadAvailableDocuments().isEmpty)
    }

    func testPersistenceAcrossStoreReloadForExternalBookmark() throws {
        let url = try writeTempPDF(named: "Persist", pageCount: 1, uniqueContent: true)
        _ = try store.recordActiveDocument(
            sourceURL: url,
            displayName: "Persist",
            pageCount: 1,
            ownership: .external
        )

        let reloaded = RecentDocumentsStore(rootDirectory: root)
        let entries = reloaded.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].displayName, "Persist")
        let resolved = try reloaded.resolveDocumentURL(for: entries[0])
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.url.path))
    }

    func testAppOwnedBlankDocumentPersistsAuthoritativeFile() throws {
        let record = try store.createAppOwnedBlankDocument(displayName: "Untitled")
        XCTAssertEqual(record.ownership, .appOwned)
        XCTAssertNotNil(record.relativeFilePath)

        let reloaded = RecentDocumentsStore(rootDirectory: root)
        let entries = reloaded.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        let url = try XCTUnwrap(reloaded.appOwnedFileURL(for: entries[0]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testImportPDFRecordsExternalRecentDocument() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let url = try writeTempPDF(named: "Imported", pageCount: 1, uniqueContent: true)

        await viewModel.importPDF(from: url, ownership: .external)

        XCTAssertTrue(viewModel.hasDocument)
        let entries = isolated.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.displayName, "Imported")
        XCTAssertEqual(entries.first?.ownership, .external)
        XCTAssertEqual(viewModel.activeDocumentOrigin, .external(identityKey: entries[0].identityKey))
    }

    func testCreateBlankDocumentOpensEditorAndRecordsAppOwned() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)

        await viewModel.createBlankDocument()

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 1)
        XCTAssertEqual(viewModel.documentName, "Untitled")
        let entries = isolated.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.ownership, .appOwned)
        if case .appOwned(let id) = viewModel.activeDocumentOrigin {
            XCTAssertEqual(id, entries[0].id)
        } else {
            XCTFail("Expected app-owned origin")
        }
    }

    func testScanStyleAppOwnedImportRecordsRecent() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let url = try writeTempPDF(named: "Scanned", pageCount: 2, uniqueContent: true)

        await viewModel.importPDF(from: url, ownership: .appOwned)

        let entries = isolated.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.ownership, .appOwned)
        XCTAssertNotNil(isolated.appOwnedFileURL(for: entries[0]))
    }

    func testIncomingDocumentURLRecordsExternal() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let url = try writeTempPDF(named: "OpenIn", pageCount: 1, uniqueContent: true)

        await viewModel.handleIncomingDocumentURL(url)

        let entries = isolated.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.ownership, .external)
    }

    func testOpenRecentExternalDocumentLoadsLatestFileBytes() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentLatest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Mutable.pdf")
        try makePDFData(named: "V1", pageCount: 1).write(to: url)

        await viewModel.importPDF(from: url, ownership: .external)
        await viewModel.closeSession()

        try makePDFData(named: "V2", pageCount: 3).write(to: url)

        let record = try XCTUnwrap(isolated.loadAvailableDocuments().first)
        await viewModel.openRecentDocument(record)

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 3)
        XCTAssertEqual(viewModel.documentName, "Mutable")
    }

    func testOpenRecentAppOwnedAfterExportWriteback() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)

        await viewModel.createBlankDocument()
        let beforeID = try XCTUnwrap(isolated.loadAvailableDocuments().first?.id)
        guard let firstPage = viewModel.pages.first else {
            return XCTFail("Missing page")
        }
        viewModel.duplicatePage(id: firstPage.id)
        XCTAssertEqual(viewModel.pageCount, 2)

        let exportURL = try viewModel.exportPDF()
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        let ownedURL = isolated.appOwnedFileURL(id: beforeID)
        let ownedDocument = try XCTUnwrap(PDFDocument(url: ownedURL))
        XCTAssertEqual(ownedDocument.pageCount, 2, "Export must write edited bytes back to app-owned file")
        XCTAssertEqual(try Data(contentsOf: ownedURL), try Data(contentsOf: exportURL))

        await viewModel.closeSession()
        let record = try XCTUnwrap(isolated.loadAvailableDocuments().first)
        await viewModel.openRecentDocument(record)

        XCTAssertTrue(viewModel.hasDocument)
        XCTAssertEqual(viewModel.pageCount, 2)
        XCTAssertEqual(record.id, beforeID)
    }

    func testMaxStoredDocumentsEvictsOldestAndDeletesAppOwnedFile() throws {
        var keptIDs: [UUID] = []
        for index in 0..<RecentDocumentsStore.maxStoredDocuments {
            let record = try store.createAppOwnedBlankDocument(displayName: "Keep\(index)")
            keptIDs.append(record.id)
        }
        let oldestID = keptIDs[0]
        let oldestURL = store.appOwnedFileURL(id: oldestID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldestURL.path))

        let overflow = try store.createAppOwnedBlankDocument(displayName: "Overflow")
        let entries = store.loadAvailableDocuments()
        XCTAssertEqual(entries.count, RecentDocumentsStore.maxStoredDocuments)
        XCTAssertEqual(entries.first?.id, overflow.id)
        XCTAssertFalse(entries.contains(where: { $0.id == oldestID }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldestURL.path))
    }

    func testLegacySchemaIndexIsIgnoredAndLegacyFilesDirectoryRemoved() throws {
        let legacyRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LegacyRecent-\(UUID().uuidString)", isDirectory: true)
        let legacyFiles = legacyRoot.appendingPathComponent(RecentDocumentsStore.legacyFilesDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: legacyFiles, withIntermediateDirectories: true)
        let leftoverPDF = legacyFiles.appendingPathComponent("legacy.pdf")
        try makePDFData(named: "Legacy", pageCount: 1).write(to: leftoverPDF)

        let v1Index = """
        [{"id":"\(UUID().uuidString)","displayName":"Old","lastOpenedAt":"2020-01-01T00:00:00Z","relativeFilePath":"files/legacy.pdf","contentFingerprint":"abc","pageCount":1,"kind":"document"}]
        """
        try Data(v1Index.utf8).write(to: legacyRoot.appendingPathComponent(RecentDocumentsStore.indexFileName))

        let migrated = RecentDocumentsStore(rootDirectory: legacyRoot)
        XCTAssertTrue(migrated.loadAvailableDocuments().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFiles.path))

        try? FileManager.default.removeItem(at: legacyRoot)
    }

    func testCancelledScanAcquisitionDoesNotRecordRecent() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let editor = PDFEditorViewModel(recentDocumentsStore: isolated)
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let permissionChecker = MockScanCameraPermissionChecker()
        permissionChecker.status = .authorized
        let scannerAvailability = MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        let session = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: scannerAvailability
        )

        let ready = await session.beginCameraScanFlow()
        XCTAssertTrue(ready)
        session.handleVisionKitScanCancelled()

        XCTAssertNil(session.document)
        XCTAssertTrue(isolated.loadAvailableDocuments().isEmpty)
        XCTAssertFalse(editor.hasDocument)
    }

    func testOpenMissingRecentDocumentCleansUp() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let viewModel = PDFEditorViewModel(recentDocumentsStore: isolated)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentMissing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Missing.pdf")
        try makePDFData(named: "Missing", pageCount: 1).write(to: url)

        let record = try isolated.recordActiveDocument(
            sourceURL: url,
            displayName: "Missing",
            pageCount: 1,
            ownership: .external
        )
        try FileManager.default.removeItem(at: url)

        await viewModel.openRecentDocument(record)

        XCTAssertFalse(viewModel.hasDocument)
        XCTAssertTrue(isolated.loadAvailableDocuments().isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testThumbnailGeneratedForRecordedDocument() throws {
        let url = try writeTempPDF(named: "Thumb", pageCount: 1, uniqueContent: true)
        let record = try store.recordActiveDocument(
            sourceURL: url,
            displayName: "Thumb",
            pageCount: 1,
            ownership: .external
        )
        XCTAssertNotNil(record.thumbnailRelativePath)
        XCTAssertNotNil(store.loadThumbnailImage(for: record))
    }

    func testHandoffRecordsAppOwnedRecent() async throws {
        let isolated = RecentDocumentsStore(rootDirectory: root)
        let editorViewModel = PDFEditorViewModel(recentDocumentsStore: isolated)
        let pdfURL = try writeTempPDF(named: "Handoff", pageCount: 1, uniqueContent: true)
        let handoff = ScanEditorHandoffService()

        try await handoff.handoff(pdfURL: pdfURL, to: editorViewModel)

        let entries = isolated.loadAvailableDocuments()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.ownership, .appOwned)
    }

    // MARK: - Fixtures

    private func writeTempPDF(named name: String, pageCount: Int, uniqueContent: Bool) throws -> URL {
        let data = try makePDFData(named: uniqueContent ? "\(name)-\(UUID().uuidString)" : name, pageCount: pageCount)
        return try writePDFData(data, named: name)
    }

    private func writePDFData(_ data: Data, named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecentDocFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name).appendingPathExtension("pdf")
        try data.write(to: url)
        return url
    }

    private func makePDFData(named name: String, pageCount: Int) throws -> Data {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let page = PDFPage()
            let annotation = PDFAnnotation(
                bounds: CGRect(x: 40, y: 700, width: 400, height: 40),
                forType: .freeText,
                withProperties: nil
            )
            annotation.contents = "\(name)-\(index)"
            page.addAnnotation(annotation)
            document.insert(page, at: document.pageCount)
        }
        guard let data = document.dataRepresentation() else {
            throw NSError(domain: "RecentDocumentsTests", code: 1)
        }
        return data
    }
}
