import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftVisualBatchRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        viewModel = ScanDraftSessionViewModel(storage: storage)
    }

    func testApplyToAllPreservesPageGeometry() async throws {
        let pages = try await makeDraftWithDistinctGeometry(count: 3)
        let draftID = try XCTUnwrap(viewModel.document?.id)
        let sessionDirectory = storage.sessionDirectory(for: draftID)
        let originalGeometries = viewModel.document?.pages.map(\.geometry)

        await viewModel.preparePageAdjustment(pageID: pages[0])
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .grayscale
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)

        let applied = await viewModel.applyPageAdjustment(scope: .allPages)
        XCTAssertTrue(applied)

        let resultGeometries = try XCTUnwrap(viewModel.document?.pages.map(\.geometry))
        XCTAssertEqual(resultGeometries, originalGeometries)
        XCTAssertTrue(viewModel.document?.pages.allSatisfy { $0.visualAdjustments.mode == .grayscale } == true)
        XCTAssertEqual(viewModel.document?.sessionDefaultVisualAdjustments.mode, .grayscale)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDirectory.path))
    }

    func testApplyToSelectedPagesOnlyUpdatesSelection() async throws {
        let pages = try await makeDraftWithDistinctGeometry(count: 3)
        let selectedIDs = Set([pages[0], pages[2]])

        viewModel.enterMultiSelectionMode()
        for id in selectedIDs {
            viewModel.toggleBatchSelection(pageID: id)
        }

        await viewModel.preparePageAdjustment(pageID: pages[0])
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .enhanced
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)

        let applied = await viewModel.applyPageAdjustment(scope: .selectedPages)
        XCTAssertTrue(applied)

        XCTAssertEqual(viewModel.document?.pages[0].visualAdjustments.mode, .enhanced)
        XCTAssertEqual(viewModel.document?.pages[1].visualAdjustments.mode, .original)
        XCTAssertEqual(viewModel.document?.pages[2].visualAdjustments.mode, .enhanced)
        XCTAssertEqual(viewModel.document?.sessionDefaultVisualAdjustments.mode, .original)
    }

    func testEmptySelectedPagesIsRejected() async throws {
        _ = try await makeDraftWithDistinctGeometry(count: 2)
        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        await viewModel.preparePageAdjustment(pageID: pageID)
        let applied = await viewModel.applyPageAdjustment(scope: .selectedPages)

        XCTAssertFalse(applied)
        XCTAssertEqual(viewModel.errorMessage, ScanDraftError.emptyBatchSelection.localizedDescription)
    }

    func testBatchSelectionIsIndependentFromPreviewSelection() async throws {
        let pages = try await makeDraftWithDistinctGeometry(count: 3)

        viewModel.enterMultiSelectionMode()
        viewModel.toggleBatchSelection(pageID: pages[2])
        viewModel.selectPage(id: pages[0])

        XCTAssertEqual(viewModel.document?.selectedPageID, pages[0])
        XCTAssertEqual(viewModel.batchSelectionPageIDs, [pages[2]])
    }

    func testExitSelectionModeClearsBatchSelection() async throws {
        let pages = try await makeDraftWithDistinctGeometry(count: 2)
        viewModel.enterMultiSelectionMode()
        viewModel.toggleBatchSelection(pageID: pages[0])

        viewModel.exitMultiSelectionMode()

        XCTAssertFalse(viewModel.isMultiSelectionMode)
        XCTAssertTrue(viewModel.batchSelectionPageIDs.isEmpty)
    }

    func testResolvedTargetPageIDsFollowDocumentOrder() async throws {
        let pages = try await makeDraftWithDistinctGeometry(count: 4)
        viewModel.enterMultiSelectionMode()
        viewModel.toggleBatchSelection(pageID: pages[3])
        viewModel.toggleBatchSelection(pageID: pages[1])

        let ordered = viewModel.resolvedTargetPageIDs(for: .selectedPages, sourcePageID: pages[0])
        XCTAssertEqual(ordered, [pages[1], pages[3]])
    }

    func testNewlyImportedPagesInheritSessionDefaultsAfterApplyToAll() async throws {
        let pages = try await makeDraftWithDistinctGeometry(count: 1)

        await viewModel.preparePageAdjustment(pageID: pages[0])
        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .blackAndWhite
        adjustments.contrast = 0.2
        viewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)

        let applied = await viewModel.applyPageAdjustment(scope: .allPages)
        XCTAssertTrue(applied)

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        await importPhotos(count: 1)

        let newPage = try XCTUnwrap(viewModel.document?.pages.last)
        XCTAssertEqual(newPage.visualAdjustments.mode, .blackAndWhite)
        XCTAssertEqual(newPage.geometry.rotation, 0)
    }

    @discardableResult
    private func makeDraftWithDistinctGeometry(count: Int) async throws -> [UUID] {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: count)
        let pageIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))

        for (index, pageID) in pageIDs.enumerated() {
            var geometry = ScanPageGeometry.default
            geometry.rotation = (index * 90) % 360
            geometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners(
                inset: CGFloat(index) * 0.02 + 0.02
            )
            viewModel.updatePageGeometry(id: pageID, geometry: geometry)
        }

        viewModel.selectPage(id: pageIDs[0])
        return pageIDs
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }
}
