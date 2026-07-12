import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFEditorViewModelRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempPDFURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        tempPDFURL = try PDFTestFixtures.makeMultiPagePDF(pageCount: 3)
        await viewModel.importPDF(from: tempPDFURL)
    }

    override func tearDown() async throws {
        if let tempPDFURL {
            try? FileManager.default.removeItem(at: tempPDFURL)
        }
        viewModel = nil
        try await super.tearDown()
    }

    func testDuplicatePageCopiesOverlaysWithNewIDsAndSharedAsset() throws {
        let sourcePage = try XCTUnwrap(viewModel.pages.first)
        let image = PDFTestFixtures.makeTestImage()
        viewModel.addImageOverlay(to: sourcePage.id, image: image, pageAspectRatio: 612.0 / 792.0)

        let originalOverlays = viewModel.overlayObjects(for: sourcePage.id)
        XCTAssertEqual(originalOverlays.count, 1)

        viewModel.duplicatePage(id: sourcePage.id)

        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != sourcePage.id && $0.originalPageIndex == sourcePage.originalPageIndex }))
        let copiedOverlays = viewModel.overlayObjects(for: duplicatePage.id)

        XCTAssertEqual(copiedOverlays.count, originalOverlays.count)
        XCTAssertNotEqual(copiedOverlays[0].id, originalOverlays[0].id)
        XCTAssertEqual(copiedOverlays[0].pageItemID, duplicatePage.id)
        XCTAssertEqual(copiedOverlays[0].imageAssetID, originalOverlays[0].imageAssetID)
        XCTAssertEqual(copiedOverlays[0].position, originalOverlays[0].position)
        XCTAssertEqual(copiedOverlays[0].size, originalOverlays[0].size)
        XCTAssertEqual(copiedOverlays[0].zIndex, originalOverlays[0].zIndex)
    }

    func testUpdatingCopiedOverlayDoesNotMutateOriginal() throws {
        let sourcePage = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: sourcePage.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.duplicatePage(id: sourcePage.id)

        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != sourcePage.id }))
        var copiedOverlay = try XCTUnwrap(viewModel.overlayObjects(for: duplicatePage.id).first)
        copiedOverlay.position = CGPoint(x: 0.2, y: 0.3)
        copiedOverlay.size = CGSize(width: 0.4, height: 0.4)
        viewModel.updateOverlay(copiedOverlay)

        let originalOverlay = try XCTUnwrap(viewModel.overlayObjects(for: sourcePage.id).first)
        XCTAssertEqual(originalOverlay.position, CGPoint(x: 0.5, y: 0.5))
        XCTAssertNotEqual(originalOverlay.size.width, 0.4, accuracy: 0.001)
    }

    func testUndoAfterDuplicateRemovesDuplicatePageAndCopiedOverlays() throws {
        let sourcePage = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: sourcePage.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let revisionBeforeDuplicate = viewModel.overlayRevision(for: sourcePage.id)

        viewModel.duplicatePage(id: sourcePage.id)
        XCTAssertEqual(viewModel.pages.count, 4)

        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != sourcePage.id && $0.originalPageIndex == sourcePage.originalPageIndex }))
        XCTAssertEqual(viewModel.overlayObjects(for: duplicatePage.id).count, 1)

        viewModel.undo()

        XCTAssertEqual(viewModel.pages.count, 3)
        XCTAssertTrue(viewModel.pages.allSatisfy { $0.id != duplicatePage.id })
        XCTAssertEqual(viewModel.overlayObjects(for: duplicatePage.id).count, 0)
        XCTAssertEqual(viewModel.overlayObjects(for: sourcePage.id).count, 1)
        XCTAssertEqual(viewModel.overlayRevision(for: sourcePage.id), revisionBeforeDuplicate)
    }

    func testUndoDuplicatePrunesOrphanAssetsOnlyWhenUnreferenced() throws {
        let sourcePage = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: sourcePage.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let assetID = try XCTUnwrap(viewModel.overlayObjects(for: sourcePage.id).first?.imageAssetID)

        viewModel.duplicatePage(id: sourcePage.id)
        viewModel.undo()

        XCTAssertNotNil(viewModel.imageAsset(for: assetID))

        let overlayID = try XCTUnwrap(viewModel.overlayObjects(for: sourcePage.id).first?.id)
        viewModel.deleteOverlay(id: overlayID, pageItemID: sourcePage.id)
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))

        viewModel.undo()
        viewModel.undo()
        viewModel.rotatePage(id: sourcePage.id)
        XCTAssertNil(viewModel.imageAsset(for: assetID))
    }

    func testOverlayRevisionBumpsOnAddMoveResizeAndDelete() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let initialRevision = viewModel.overlayRevision(for: page.id)

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), initialRevision + 1)

        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        overlay.position = CGPoint(x: 0.4, y: 0.4)
        viewModel.updateOverlay(overlay)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), initialRevision + 2)

        overlay.size = CGSize(width: 0.3, height: 0.3)
        viewModel.updateOverlay(overlay)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), initialRevision + 3)

        viewModel.deleteOverlay(id: overlay.id, pageItemID: page.id)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), initialRevision + 4)
    }

    func testDuplicateAndUndoKeepOverlayRevisionsConsistent() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let revisionBeforeDuplicate = viewModel.overlayRevision(for: page.id)

        viewModel.duplicatePage(id: page.id)
        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != page.id && $0.originalPageIndex == page.originalPageIndex }))
        XCTAssertEqual(viewModel.overlayRevision(for: duplicatePage.id), 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), revisionBeforeDuplicate)
        XCTAssertEqual(viewModel.overlayRevision(for: duplicatePage.id), 0)
    }

    func testReorderChangesPageOrder() throws {
        let firstID = viewModel.pages[0].id
        let secondID = viewModel.pages[1].id
        let thirdID = viewModel.pages[2].id

        viewModel.reorderPage(from: 0, to: 2)

        XCTAssertEqual(viewModel.pages.map(\.id), [secondID, thirdID, firstID])
    }

    func testDeleteRemovesPageAndOverlays() throws {
        let page = viewModel.pages[1]
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )

        viewModel.deletePage(id: page.id)

        XCTAssertEqual(viewModel.pages.count, 2)
        XCTAssertTrue(viewModel.pages.allSatisfy { $0.id != page.id })
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
    }

    func testRotateUpdatesPageItemRotation() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        XCTAssertEqual(page.rotation, 0)

        viewModel.rotatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)

        viewModel.rotatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.first?.rotation, 180)
    }

    func testDuplicatePreservesOriginalPageIndexAndCopiesOverlays() throws {
        let page = viewModel.pages[2]
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFixtures.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )

        viewModel.duplicatePage(id: page.id)

        let duplicate = try XCTUnwrap(viewModel.pages.first(where: { $0.id != page.id && $0.originalPageIndex == page.originalPageIndex }))
        XCTAssertEqual(duplicate.originalPageIndex, 2)
        XCTAssertEqual(viewModel.overlayObjects(for: duplicate.id).count, 1)
    }
}
