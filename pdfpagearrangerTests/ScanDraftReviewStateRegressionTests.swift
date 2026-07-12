import XCTest
@testable import pdfpagearranger

final class ScanDraftReviewStateRegressionTests: XCTestCase {
    func testNewMultiPageDraftSelectsFirstPage() {
        var document = ScanDraftDocument()
        let ids = (0..<3).map { _ in UUID() }

        document.addPages(ids.map { id in
            ScanDraftPage(
                id: id,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/\(id.uuidString).jpg"),
                originalPixelSize: CGSize(width: 100, height: 100)
            )
        })

        XCTAssertEqual(document.selectedPageID, ids.first)
        XCTAssertEqual(document.pages.count, 3)
    }

    func testRepairSelectionChoosesNearestValidPageWhenSelectedMissing() {
        var document = ScanDraftDocument()
        let firstID = UUID()
        let secondID = UUID()
        document.addPages([
            makePage(id: firstID, source: .camera),
            makePage(id: secondID, source: .photos)
        ])
        document.selectPage(id: UUID())

        document.repairSelectionIfNeeded()

        XCTAssertEqual(document.selectedPageID, firstID)
    }

    func testRepairSelectionClearsWhenDraftEmpty() {
        var document = ScanDraftDocument()
        document.selectPage(id: UUID())

        document.repairSelectionIfNeeded()

        XCTAssertNil(document.selectedPageID)
        XCTAssertTrue(document.selectedPageIDs.isEmpty)
    }

    func testMixedSourcePagesRemainInSingleOrderedDocument() {
        var document = ScanDraftDocument()
        let cameraID = UUID()
        let photosID = UUID()
        document.addPage(makePage(id: cameraID, source: .camera))
        document.addPage(makePage(id: photosID, source: .photos))

        XCTAssertEqual(document.pages.map(\.id), [cameraID, photosID])
        XCTAssertEqual(document.pages.map(\.sourceType), [.camera, .photos])
    }

    func testRemoveFinalSelectedPageSelectsNewFinalPage() {
        var document = ScanDraftDocument()
        let firstID = UUID()
        let secondID = UUID()
        document.addPages([
            makePage(id: firstID, source: .camera),
            makePage(id: secondID, source: .photos)
        ])
        document.selectPage(id: secondID)

        XCTAssertTrue(document.removePage(id: secondID))
        XCTAssertEqual(document.selectedPageID, firstID)
    }

    func testCloseIntentRequiresConfirmationForModifiedDraft() {
        var document = ScanDraftDocument()
        document.addPage(makePage(id: UUID(), source: .camera))

        XCTAssertTrue(document.hasUnsavedChanges)
    }

    private func makePage(id: UUID, source: ScanPageSource) -> ScanDraftPage {
        ScanDraftPage(
            id: id,
            sourceType: source,
            originalImage: ScanDraftImageReference(relativePath: "originals/\(id.uuidString).jpg"),
            originalPixelSize: CGSize(width: 120, height: 160)
        )
    }
}

@MainActor
final class ScanDraftSessionViewModelReviewRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        viewModel = ScanDraftSessionViewModel(storage: storage)
    }

    func testSelectPageUpdatesSelectedIdentity() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)

        let secondID = try XCTUnwrap(viewModel.document?.pages.last?.id)
        viewModel.selectPage(id: secondID)

        XCTAssertEqual(viewModel.document?.selectedPageID, secondID)
        XCTAssertEqual(viewModel.pageNumber(for: secondID), 2)
    }

    func testAddPagesPreservesCurrentSelection() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let existingID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        viewModel.selectPage(id: existingID)

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        await importPhotos(count: 2)

        XCTAssertEqual(viewModel.document?.pages.count, 3)
        XCTAssertEqual(viewModel.document?.selectedPageID, existingID)
        XCTAssertEqual(viewModel.navigationPath.last, .draftReview)
    }

    func testOpenAdjustmentNavigatesWithSelectedPageIdentity() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        viewModel.selectPage(id: pageID)

        viewModel.openAdjustmentForSelectedPage()

        try await waitForAdjustmentNavigation(pageID: pageID)

        XCTAssertEqual(viewModel.navigationPath.last, .pageAdjustment(pageID: pageID))
        XCTAssertEqual(viewModel.adjustmentSession?.pageID, pageID)
    }

    func testCloseIntentRequiresDiscardConfirmationAfterImport() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)

        XCTAssertEqual(viewModel.closeDraftIntent(), .confirmDiscard)
    }

    func testDiscardDraftSessionWithCleanupRemovesSessionFiles() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let sessionID = try XCTUnwrap(viewModel.document?.id)

        XCTAssertTrue(viewModel.discardDraftSessionWithCleanup())
        XCTAssertNil(viewModel.document)
        XCTAssertFalse(storage.sessionExists(for: sessionID))
    }

    func testRepairSelectionAfterInvalidSelectedPage() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        let firstID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        viewModel.selectPage(id: UUID())

        viewModel.repairSelectionIfNeeded()

        XCTAssertEqual(viewModel.document?.selectedPageID, firstID)
    }

    func testReturningFromAdjustmentKeepsSameDraftAndSelection() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        let draftID = try XCTUnwrap(viewModel.document?.id)
        let selectedID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        viewModel.openAdjustmentForSelectedPage()
        viewModel.navigateToDraftReview()

        XCTAssertEqual(viewModel.document?.id, draftID)
        XCTAssertEqual(viewModel.document?.selectedPageID, selectedID)
        XCTAssertEqual(viewModel.navigationPath, [.draftReview])
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
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
