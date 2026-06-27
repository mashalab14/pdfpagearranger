import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFOverlayUndoRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        pdfService = PDFService()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        viewModel = nil
        pdfService = nil
        try await super.tearDown()
    }

    func testUndoAfterAddRemovesOverlayAndRestoresRevision() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let revisionBefore = viewModel.overlayRevision(for: page.id)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), revisionBefore + 1)

        viewModel.undo()

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), revisionBefore)
    }

    func testUndoAfterMoveRestoresPosition() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.undo()

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let originalPosition = overlay.position

        overlay.position = CGPoint(x: 0.2, y: 0.8)
        viewModel.updateOverlay(overlay)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.position.x ?? 0, 0.2, accuracy: 0.001)

        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.position.x, originalPosition.x, accuracy: 0.001)
        XCTAssertEqual(restored.position.y, originalPosition.y, accuracy: 0.001)
    }

    func testUndoAfterResizeRestoresSize() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.undo()

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let originalSize = overlay.size

        overlay.size = CGSize(width: 0.5, height: 0.5)
        viewModel.updateOverlay(overlay)

        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.size.width, originalSize.width, accuracy: 0.001)
        XCTAssertEqual(restored.size.height, originalSize.height, accuracy: 0.001)
    }

    func testUndoAfterDeleteRestoresOverlayAndImageAsset() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.undo()

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let overlayID = overlay.id
        let assetID = try XCTUnwrap(overlay.imageAssetID)
        let revisionBeforeDelete = viewModel.overlayRevision(for: page.id)

        viewModel.deleteOverlay(id: overlayID, pageItemID: page.id)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
        XCTAssertNil(viewModel.imageAsset(for: assetID))

        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.id, overlayID)
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), revisionBeforeDelete)
    }

    func testUndoAfterDeleteKeepsSharedImageAssetWhenDuplicateReferencesIt() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.undo()

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.duplicatePage(id: page.id)

        let sourceOverlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != page.id }))
        let duplicateOverlay = try XCTUnwrap(viewModel.overlayObjects(for: duplicatePage.id).first)
        let assetID = try XCTUnwrap(sourceOverlay.imageAssetID)

        viewModel.deleteOverlay(id: sourceOverlay.id, pageItemID: page.id)
        XCTAssertNotNil(viewModel.imageAsset(for: assetID), "Shared asset must remain while duplicate references it")

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))
        XCTAssertEqual(
            viewModel.overlayObjects(for: duplicatePage.id).first?.imageAssetID,
            duplicateOverlay.imageAssetID
        )
    }

    func testUndoDuplicatePageWithOverlaysStillWorksAfterOverlayUndoChanges() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )

        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        overlay.position = CGPoint(x: 0.25, y: 0.75)
        viewModel.updateOverlay(overlay)

        viewModel.duplicatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.count, 2)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.count, 1)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
    }

    func testExportIncludesOverlaysAfterOverlayUndo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        overlay.position = CGPoint(x: 0.3, y: 0.3)
        viewModel.updateOverlay(overlay)

        viewModel.undo()

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageCount(1, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testThumbnailRevisionChangesAfterOverlayUndo() async throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let document = try XCTUnwrap(viewModel.sourceDocument)
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(color: .green),
            pageAspectRatio: 612.0 / 792.0
        )
        let revisionAfterAdd = viewModel.overlayRevision(for: page.id)
        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let images = viewModel.overlayImages(for: page.id)

        let beforeUndo = await ThumbnailService.shared.thumbnail(
            for: page,
            document: document,
            overlays: [overlay],
            overlayImages: images,
            revision: revisionAfterAdd
        )

        viewModel.undo()
        let revisionAfterUndo = viewModel.overlayRevision(for: page.id)
        XCTAssertLessThan(revisionAfterUndo, revisionAfterAdd)

        let afterUndo = await ThumbnailService.shared.thumbnail(
            for: page,
            document: document,
            overlays: [],
            overlayImages: [:],
            revision: revisionAfterUndo
        )

        XCTAssertNotNil(beforeUndo)
        XCTAssertNotNil(afterUndo)
        XCTAssertNotEqual(beforeUndo?.pngData(), afterUndo?.pngData())
    }

    func testUpdateOverlayWithNoChangesDoesNotPushUndoEntry() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        viewModel.undo()

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertTrue(viewModel.canUndo)

        viewModel.updateOverlay(overlay)
        viewModel.undo()

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
    }
}
