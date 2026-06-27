import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFSignatureOverlayRegressionTests: XCTestCase {
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

    func testAddSignatureCreatesSignaturePageObject() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        XCTAssertEqual(signature.type, .signature)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.type, .signature)
    }

    func testSignatureUsesImageAssetStorage() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        let assetID = try XCTUnwrap(signature.imageAssetID)

        XCTAssertNotNil(viewModel.imageAsset(for: assetID))
        XCTAssertEqual(viewModel.overlayImages(for: page.id).keys.sorted { $0.uuidString < $1.uuidString }, [assetID])
    }

    func testSignaturePersistsInPageObjectsByPage() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        let persisted = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(persisted.id, signature.id)
        XCTAssertEqual(persisted.type, .signature)
        XCTAssertEqual(persisted.imageAssetID, signature.imageAssetID)
    }

    func testDuplicatePageCopiesSignatureOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        viewModel.duplicatePage(id: page.id)

        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != page.id }))
        let copied = try XCTUnwrap(viewModel.overlayObjects(for: duplicatePage.id).first)

        XCTAssertEqual(copied.type, .signature)
        XCTAssertNotEqual(copied.id, signature.id)
        XCTAssertEqual(copied.imageAssetID, signature.imageAssetID)
        XCTAssertEqual(copied.position, signature.position)
        XCTAssertEqual(copied.size.width, signature.size.width, accuracy: 0.001)
    }

    func testUndoAfterAddSignatureRemovesOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let revisionBefore = viewModel.overlayRevision(for: page.id)

        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)

        viewModel.undo()

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
        XCTAssertEqual(viewModel.overlayRevision(for: page.id), revisionBefore)
    }

    func testUndoAfterMoveSignatureRestoresPosition() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        viewModel.undo()

        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        var signature = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let originalPosition = signature.position

        signature.position = CGPoint(x: 0.2, y: 0.8)
        viewModel.updateOverlay(signature)

        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.position.x, originalPosition.x, accuracy: 0.001)
        XCTAssertEqual(restored.position.y, originalPosition.y, accuracy: 0.001)
    }

    func testUndoAfterResizeSignatureRestoresSize() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        viewModel.undo()

        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        var signature = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let originalSize = signature.size

        signature.size = CGSize(width: 0.6, height: 0.2)
        viewModel.updateOverlay(signature)

        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.size.width, originalSize.width, accuracy: 0.001)
        XCTAssertEqual(restored.size.height, originalSize.height, accuracy: 0.001)
    }

    func testUndoAfterDeleteSignatureRestoresOverlayAndAsset() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        viewModel.undo()

        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)
        let signature = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let assetID = try XCTUnwrap(signature.imageAssetID)

        viewModel.deleteOverlay(id: signature.id, pageItemID: page.id)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
        XCTAssertNil(viewModel.imageAsset(for: assetID))

        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.type, .signature)
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))
    }

    func testExportIncludesSignatureOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(1, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
        XCTAssertNotNil(PDFDocument(url: exportURL)?.page(at: 0))
    }

    func testExportWithSignaturePreservesSelectableText() async throws {
        let expectedText = "SelectableExportText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "SignatureText", text: expectedText)
        tempURLs.append(sourceURL)

        await viewModel.importPDF(from: sourceURL)
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testSignatureUsesRasterImageAssetHelper() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.makeSignatureOverlay(pageItemID: page.id)

        XCTAssertTrue(signature.usesRasterImageAsset)

        let textObject = PageObject(pageItemID: page.id, type: .text, position: .zero, size: .zero)
        XCTAssertFalse(textObject.usesRasterImageAsset)
    }

    func testImageOverlayRegressionStillPassesAfterSignatureSupport() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let imageOverlay = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)

        XCTAssertEqual(imageOverlay.type, .image)
        XCTAssertTrue(imageOverlay.usesRasterImageAsset)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageCount(1, in: exportURL)
    }
}
