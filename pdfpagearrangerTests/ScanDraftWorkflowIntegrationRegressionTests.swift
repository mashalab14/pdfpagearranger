import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftWorkflowIntegrationRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        viewModel = ScanDraftSessionViewModel(storage: storage)
    }

    func testMixedSourceDraftPreservesOrderThroughPDFGeneration() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let existingIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))

        var defaults = ScanVisualAdjustments.neutral
        defaults.mode = .enhanced
        viewModel.updateSessionDefaultVisualAdjustments(defaults)

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        await importPhotosToExisting(count: 2)
        try await waitForProcessingToFinish()

        let finalIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        XCTAssertEqual(finalIDs.count, 4)
        XCTAssertEqual(Array(finalIDs.prefix(2)), existingIDs)
        XCTAssertEqual(viewModel.document?.pages[0].visualAdjustments.mode, .original)
        XCTAssertEqual(viewModel.document?.pages[1].visualAdjustments.mode, .original)
        XCTAssertEqual(viewModel.document?.pages[2].visualAdjustments.mode, .enhanced)
        XCTAssertEqual(viewModel.document?.pages[3].visualAdjustments.mode, .enhanced)

        let pdfURL = try await viewModel.generatePDF(displayName: "Mixed Draft")
        XCTAssertEqual(PDFDocument(url: pdfURL)?.pageCount, 4)
    }

    func testDiscardDuringProcessingDoesNotSurfaceStaleError() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))

        let importTask = Task {
            await viewModel.handlePhotosSelection(
                orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 5),
                assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 5)
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let sessionID = try XCTUnwrap(viewModel.document?.id)
        XCTAssertTrue(viewModel.discardDraftSessionWithCleanup())

        await importTask.value
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNil(viewModel.document)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isProcessingPages)
        XCTAssertFalse(storage.sessionExists(for: sessionID))
    }

    func testPhotosCancellationDoesNotShowError() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let selectedID = try XCTUnwrap(viewModel.document?.selectedPageID)
        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        viewModel.handlePhotosPickerCancelled()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.document?.selectedPageID, selectedID)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testReturningFromAdjustmentPreservesSelectionAndDraft() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 3)
        try await waitForProcessingToFinish()

        let draftID = try XCTUnwrap(viewModel.document?.id)
        let secondID = try XCTUnwrap(viewModel.document?.pages[1].id)
        viewModel.selectPage(id: secondID)
        viewModel.openAdjustmentForSelectedPage()
        try await waitForAdjustmentNavigation(pageID: secondID)

        viewModel.navigateToDraftReview()

        XCTAssertEqual(viewModel.document?.id, draftID)
        XCTAssertEqual(viewModel.document?.selectedPageID, secondID)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testHandoffUsesSingleEditorImportPath() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let editorViewModel = PDFEditorViewModel()
        _ = try await viewModel.generatePDF()
        try await viewModel.handoffToEditor(editorViewModel: editorViewModel)

        XCTAssertTrue(editorViewModel.hasDocument)
        XCTAssertEqual(editorViewModel.pageCount, 2)
        XCTAssertNotNil(viewModel.document)
        XCTAssertTrue(storage.sessionExists(for: try XCTUnwrap(viewModel.document?.id)))
    }

    func testDeletePageRemovesOnlyDeletedAssets() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let pageIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        let sessionDirectory = try XCTUnwrap(viewModel.sessionDirectory)
        let remainingOriginal = "originals/\(pageIDs[0].uuidString).jpg"
        let deletedOriginal = "originals/\(pageIDs[1].uuidString).jpg"

        viewModel.deletePages(ids: [pageIDs[1]])

        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionDirectory.appendingPathComponent(deletedOriginal).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDirectory.appendingPathComponent(remainingOriginal).path))
        XCTAssertEqual(viewModel.document?.pages.count, 1)
    }

    func testGeometryRemainsPageSpecificAfterApplyToAll() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let firstID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        let secondID = try XCTUnwrap(viewModel.document?.pages.last?.id)

        var firstGeometry = ScanPageGeometry.default
        firstGeometry.rotation = 90
        viewModel.updatePageGeometry(id: firstID, geometry: firstGeometry)
        try await waitForProcessingToFinish()

        var sharedVisual = ScanVisualAdjustments.neutral
        sharedVisual.mode = .grayscale
        viewModel.applyVisualAdjustmentsToAll(sharedVisual)
        try await waitForProcessingToFinish()

        XCTAssertEqual(viewModel.document?.pages.first?.geometry.rotation, 90)
        XCTAssertEqual(viewModel.document?.pages.last?.geometry.rotation, 0)
        XCTAssertEqual(viewModel.document?.pages.first?.visualAdjustments.mode, .grayscale)
        XCTAssertEqual(viewModel.document?.pages.last?.visualAdjustments.mode, .grayscale)
        XCTAssertNotEqual(firstID, secondID)
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }

    private func importPhotosToExisting(count: Int) async {
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }

    private func waitForProcessingToFinish(timeoutNanoseconds: UInt64 = 5_000_000_000) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if viewModel.isProcessingPages == false,
               viewModel.document?.pages.allSatisfy({ $0.processingState == .ready }) == true {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for page processing")
    }

    private func waitForAdjustmentNavigation(pageID: UUID, timeoutNanoseconds: UInt64 = 2_000_000_000) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if viewModel.navigationPath.last == .pageAdjustment(pageID: pageID),
               viewModel.adjustmentSession?.pageID == pageID {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for page adjustment navigation")
    }
}

final class ScanDraftWorkflowStateGuardRegressionTests: XCTestCase {
    func testDocumentUpdatePageIgnoresUnknownPageID() {
        var document = ScanDraftDocument()
        let pageID = UUID()
        document.addPage(
            ScanDraftPage(
                id: pageID,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/a.jpg"),
                originalPixelSize: CGSize(width: 100, height: 100),
                processingState: .ready,
                processingFingerprint: "before"
            )
        )

        document.updatePage(id: UUID()) { page in
            page.processingFingerprint = "stale"
        }

        XCTAssertEqual(document.pages.first?.processingFingerprint, "before")
    }
}
