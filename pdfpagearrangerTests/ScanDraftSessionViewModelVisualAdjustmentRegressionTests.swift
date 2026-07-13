import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftSessionViewModelVisualAdjustmentRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var edgeDetector: InMemoryScanDocumentEdgeDetector!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        edgeDetector = InMemoryScanDocumentEdgeDetector()
        viewModel = ScanDraftSessionViewModel(storage: storage, edgeDetector: edgeDetector)
    }

    func testPrepareAdjustmentLoadsCommittedVisualSettings() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .enhanced
        adjustments.brightness = 0.2
        viewModel.applyVisualAdjustments(adjustments, toPageIDs: [pageID])

        await viewModel.preparePageAdjustment(pageID: pageID)

        XCTAssertEqual(viewModel.adjustmentSession?.workingVisualAdjustments.mode, .enhanced)
        XCTAssertEqual(viewModel.adjustmentSession?.workingVisualAdjustments.brightness, 0.2)
    }

    func testVisualChangesUpdateWorkingCopyOnly() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .grayscale
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)

        XCTAssertEqual(viewModel.adjustmentSession?.workingVisualAdjustments.mode, .grayscale)
        XCTAssertEqual(viewModel.document?.pages.first?.visualAdjustments.mode, .original)
    }

    func testResetVisualAdjustmentsRestoresWorkingDefaults() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .blackAndWhite
        adjustments.contrast = 0.4
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)

        viewModel.resetAdjustmentVisualAdjustments()

        XCTAssertEqual(viewModel.adjustmentSession?.workingVisualAdjustments, .neutral)
    }

    func testCancelDiscardsVisualWorkingChanges() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        let committed = viewModel.document?.pages.first?.visualAdjustments

        await viewModel.preparePageAdjustment(pageID: pageID)
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .enhanced
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)
        viewModel.cancelPageAdjustment()

        XCTAssertEqual(viewModel.document?.pages.first?.visualAdjustments, committed)
        XCTAssertNil(viewModel.visualPreviewImage)
    }

    func testApplyCommitsVisualSettingsAndReturnsToReview() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        var geometry = try XCTUnwrap(viewModel.adjustmentSession?.workingGeometry)
        geometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners(inset: 0.05)
        geometry.perspectiveCorrectionEnabled = true
        viewModel.updateAdjustmentWorkingGeometry(geometry)

        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .enhanced
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)

        let applied = await viewModel.applyPageAdjustment(scope: .thisPage)

        XCTAssertTrue(applied)
        XCTAssertEqual(viewModel.document?.pages.first?.visualAdjustments.mode, .enhanced)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertEqual(viewModel.document?.selectedPageID, pageID)
    }

    func testLateVisualPreviewDoesNotApplyAfterCancel() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        let previewTask = Task { await viewModel.generateVisualPreview() }
        viewModel.cancelPageAdjustment()
        await previewTask.value

        XCTAssertNil(viewModel.visualPreviewImage)
        XCTAssertNil(viewModel.adjustmentSession)
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }
}
