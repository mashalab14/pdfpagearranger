import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFOverlayRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
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
        try await super.tearDown()
    }

    func testAddImageOverlayCreatesObject() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), 1)
    }

    func testMoveOverlayUpdatesPosition() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        var overlay = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)
        overlay.position = CGPoint(x: 0.25, y: 0.75)
        viewModel.updateOverlay(overlay)

        let updated = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(updated.position.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(updated.position.y, 0.75, accuracy: 0.001)
    }

    func testResizeOverlayUpdatesSize() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        var overlay = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)
        overlay.size = CGSize(width: 0.5, height: 0.5)
        viewModel.updateOverlay(overlay)

        let updated = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(updated.size.width, 0.5, accuracy: 0.001)
        XCTAssertEqual(updated.size.height, 0.5, accuracy: 0.001)
    }

    func testDeleteOverlayRemovesObjectAndCleansAssets() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlay = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)
        let assetID = try XCTUnwrap(overlay.imageAssetID)

        viewModel.deleteOverlay(id: overlay.id, pageItemID: page.id)

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
        XCTAssertNil(viewModel.imageAsset(for: assetID))
    }

    func testOverlayPersistsInViewModelState() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        _ = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id, color: .blue)

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertNotNil(viewModel.overlayImages(for: page.id).values.first)
    }
}
