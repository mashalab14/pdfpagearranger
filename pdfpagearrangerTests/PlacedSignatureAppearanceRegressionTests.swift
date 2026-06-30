import UIKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PlacedSignatureAppearanceRegressionTests: XCTestCase {
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

    func testRecolorChangesInkPixels() {
        let image = OverlayTestFactory.makeSignatureImage()
        let recolored = SignatureAppearanceEngine.recolor(image, to: SignatureInkColor.red)
        XCTAssertNotEqual(recolored.pngData(), image.pngData())
    }

    func testPlacedSignatureStoresBaselineAndSourceAsset() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let source = OverlayTestFactory.makeSignatureImage()
        let context = SignaturePlacementContext(
            sourceImage: source,
            librarySourceID: UUID(),
            baselineInkColor: .blue,
            baselineStrokeThickness: .medium
        )

        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            context: context,
            pageAspectRatio: 0.77
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(overlay.signatureBaselineInkColor, .blue)
        XCTAssertEqual(overlay.signatureBaselineStrokeThickness, .medium)
        XCTAssertNotNil(overlay.signatureSourceImageAssetID)
        XCTAssertNotNil(overlay.imageAssetID)
        XCTAssertNotEqual(overlay.signatureSourceImageAssetID, overlay.imageAssetID)
    }

    func testUpdateAppearanceDiffersFromBaseline() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let context = SignaturePlacementContext(
            sourceImage: OverlayTestFactory.makeSignatureImage(),
            librarySourceID: UUID(),
            baselineInkColor: .black,
            baselineStrokeThickness: .medium
        )
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            context: context,
            pageAspectRatio: 0.77
        )

        viewModel.updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: page.id,
            inkColor: .red,
            strokeWidthPoints: 6
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertTrue(overlay.signatureAppearanceDiffersFromBaseline)
        XCTAssertTrue(overlay.canSavePlacedSignatureToLibrary)
    }

    func testResetRestoresBaselineAppearance() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let context = SignaturePlacementContext(
            sourceImage: OverlayTestFactory.makeSignatureImage(),
            librarySourceID: UUID(),
            baselineInkColor: .black,
            baselineStrokeThickness: .medium
        )
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            context: context,
            pageAspectRatio: 0.77
        )

        viewModel.updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: page.id,
            inkColor: .purple,
            strokeWidthPoints: 6
        )
        viewModel.resetPlacedSignatureAppearance(overlayID: overlayID, pageItemID: page.id)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertFalse(overlay.signatureAppearanceDiffersFromBaseline)
        XCTAssertEqual(overlay.effectiveSignatureInkColor, .black)
        XCTAssertEqual(overlay.effectiveSignatureStrokeWidthPoints, 3)
        XCTAssertNil(overlay.signatureStrokeWidthPoints)
    }

    func testUndoWorksAfterAppearanceChange() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            image: OverlayTestFactory.makeSignatureImage(),
            pageAspectRatio: 0.77,
            placementContext: SignaturePlacementContext(
                sourceImage: OverlayTestFactory.makeSignatureImage(),
                librarySourceID: UUID(),
                baselineInkColor: .black,
                baselineStrokeThickness: .medium
            )
        )

        viewModel.updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: page.id,
            inkColor: .green,
            strokeWidthPoints: 6
        )
        viewModel.undo()

        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(restored.effectiveSignatureInkColor, .black)
        XCTAssertEqual(restored.effectiveSignatureStrokeWidthPoints, 3)
    }

    func testSaveToLibraryCreatesNewAssetWithoutMutatingPlacedOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let store = try SignatureLibraryStore.makeDefault()
        let context = SignaturePlacementContext(
            sourceImage: OverlayTestFactory.makeSignatureImage(),
            librarySourceID: UUID(),
            baselineInkColor: .black,
            baselineStrokeThickness: .medium
        )
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            context: context,
            pageAspectRatio: 0.77
        )

        viewModel.updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: page.id,
            inkColor: .red,
            strokeWidthPoints: 6
        )

        let beforeCount = store.listSignatures().count
        let newAsset = try viewModel.savePlacedSignatureToLibrary(
            overlayID: overlayID,
            pageItemID: page.id,
            store: store
        )

        XCTAssertEqual(store.listSignatures().count, beforeCount + 1)
        XCTAssertNotEqual(newAsset.id, context.librarySourceID)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(overlay.effectiveSignatureInkColor, .red)
        XCTAssertEqual(overlay.signatureLibrarySourceID, context.librarySourceID)
    }
}

final class PlacedSignatureEditorUIRegressionTests: XCTestCase {
    func testCanvasDismissesEditPopoverOnSelectionChange() throws {
        let canvas = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertTrue(canvas.contains("signatureEditOverlayID = nil"))
        XCTAssertTrue(canvas.contains("PlacedSignatureEditPopover"))
    }

    func testPageEditorWiresSignatureAppearanceCallbacks() throws {
        let source = try projectSource(named: "PageEditorView.swift", subdirectory: "Views")
        XCTAssertTrue(source.contains("onUpdateSignatureAppearance"))
        XCTAssertTrue(source.contains("onUpdateSignatureCustomColor"))
        XCTAssertTrue(source.contains("onResetSignatureAppearance"))
        XCTAssertTrue(source.contains("onSaveSignatureToLibrary"))
    }

    private func projectSource(named fileName: String, subdirectory: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot
                .appendingPathComponent("pdfpagearranger")
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(fileName),
            encoding: .utf8
        )
    }
}
