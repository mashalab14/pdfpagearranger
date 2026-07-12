import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftSessionViewModelAdjustmentRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var edgeDetector: InMemoryScanDocumentEdgeDetector!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        edgeDetector = InMemoryScanDocumentEdgeDetector()
        viewModel = ScanDraftSessionViewModel(storage: storage, edgeDetector: edgeDetector)
    }

    func testPrepareAdjustmentUsesDetectedCornersForPhotos() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        edgeDetector.result = ScanDocumentEdgeDetectionResult(
            corners: [
                ScanNormalizedPoint(x: 0.1, y: 0.1),
                ScanNormalizedPoint(x: 0.9, y: 0.1),
                ScanNormalizedPoint(x: 0.9, y: 0.9),
                ScanNormalizedPoint(x: 0.1, y: 0.9)
            ],
            confidence: 0.95
        )

        await viewModel.preparePageAdjustment(pageID: pageID)

        let session = try XCTUnwrap(viewModel.adjustmentSession)
        XCTAssertEqual(session.pageID, pageID)
        XCTAssertEqual(session.sourceType, .photos)
        XCTAssertEqual(session.workingGeometry.effectiveCorners?.count, 4)
        XCTAssertTrue(session.workingGeometry.perspectiveCorrectionEnabled)
    }

    func testCancelAdjustmentRestoresNavigationWithoutChangingDraft() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        let beforeGeometry = viewModel.document?.pages.first?.geometry

        await viewModel.preparePageAdjustment(pageID: pageID)
        viewModel.updateAdjustmentWorkingGeometry(
            ScanPageGeometry(
                userAdjustedCorners: ScanPageGeometryEngine.fullBoundsCorners(inset: 0.2),
                perspectiveCorrectionEnabled: true
            )
        )
        viewModel.navigateToPageAdjustment(pageID: pageID)
        viewModel.cancelPageAdjustment()

        XCTAssertNil(viewModel.adjustmentSession)
        XCTAssertEqual(viewModel.document?.pages.first?.geometry, beforeGeometry)
        XCTAssertEqual(viewModel.navigationPath, [.draftReview])
    }

    func testApplyAdjustmentCommitsGeometryAndReturnsToReview() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        var geometry = try XCTUnwrap(viewModel.adjustmentSession?.workingGeometry)
        geometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners(inset: 0.05)
        geometry.perspectiveCorrectionEnabled = true
        viewModel.updateAdjustmentWorkingGeometry(geometry)

        let applied = await viewModel.applyPageAdjustment()

        XCTAssertTrue(applied)
        XCTAssertNil(viewModel.adjustmentSession)
        XCTAssertEqual(viewModel.navigationPath, [.draftReview])
        XCTAssertEqual(viewModel.document?.selectedPageID, pageID)
        XCTAssertNotNil(viewModel.document?.pages.first?.processedImage)
        XCTAssertTrue(viewModel.document?.pages.first?.geometry.perspectiveCorrectionEnabled == true)
    }

    func testRotateAdjustmentGeometryUpdatesWorkingCopyOnly() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        viewModel.rotateAdjustmentGeometryClockwise()

        XCTAssertEqual(viewModel.adjustmentSession?.workingGeometry.rotation, 90)
        XCTAssertEqual(viewModel.document?.pages.first?.geometry.rotation, 0)
    }

    func testRedetectDoesNotCommitUntilApply() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        edgeDetector.result = ScanDocumentEdgeDetectionResult(
            corners: ScanPageGeometryEngine.fullBoundsCorners(inset: 0.1),
            confidence: 0.8
        )

        await viewModel.preparePageAdjustment(pageID: pageID)
        let committed = viewModel.document?.pages.first?.geometry
        XCTAssertNotEqual(viewModel.adjustmentSession?.workingGeometry.effectiveCorners, committed?.effectiveCorners)
    }

    func testCancelDuringRedetectDoesNotRestoreSession() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        edgeDetector.delayNanoseconds = 300_000_000
        edgeDetector.result = ScanDocumentEdgeDetectionResult(
            corners: ScanPageGeometryEngine.fullBoundsCorners(inset: 0.12),
            confidence: 0.75
        )

        await viewModel.preparePageAdjustment(pageID: pageID)
        let redetectTask = Task { await viewModel.redetectDocumentEdges() }
        viewModel.cancelPageAdjustment()
        await redetectTask.value

        XCTAssertNil(viewModel.adjustmentSession)
        XCTAssertEqual(viewModel.navigationPath, [.draftReview])
    }

    func testApplyMarksDraftAsModified() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        var geometry = try XCTUnwrap(viewModel.adjustmentSession?.workingGeometry)
        geometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners(inset: 0.05)
        geometry.perspectiveCorrectionEnabled = true
        viewModel.updateAdjustmentWorkingGeometry(geometry)

        _ = await viewModel.applyPageAdjustment()

        XCTAssertTrue(viewModel.document?.hasUnsavedChanges == true)
        XCTAssertEqual(viewModel.document?.selectedPageID, pageID)
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }
}
