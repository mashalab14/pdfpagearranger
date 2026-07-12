import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFUndoRedoRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []
    private var sourceURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        pdfService = PDFService()
        sourceURL = try PDFTestFactory.url(for: .multiPage)
        tempURLs.append(sourceURL)
        await viewModel.importPDF(from: sourceURL)
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

    // MARK: - Core history

    func testUndoableEditPushesUndoAndClearsRedo() throws {
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)

        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)

        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)

        viewModel.undo()
        XCTAssertTrue(viewModel.canRedo)
        XCTAssertFalse(viewModel.canUndo)

        viewModel.redo()
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
    }

    func testNewEditAfterUndoClearsRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        viewModel.undo()
        XCTAssertTrue(viewModel.canRedo)

        viewModel.rotatePage(id: page.id)
        XCTAssertFalse(viewModel.canRedo)
    }

    func testImportClearsBothStacks() async throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        viewModel.undo()
        XCTAssertTrue(viewModel.canRedo)

        let secondURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(secondURL)
        await viewModel.importPDF(from: secondURL)

        XCTAssertFalse(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
    }

    func testHistoryDepthLimitIsEnforced() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        for _ in 0..<EditorSnapshot.maxHistoryDepth + 5 {
            viewModel.rotatePage(id: page.id)
        }

        var undoCount = 0
        while viewModel.canUndo {
            viewModel.undo()
            undoCount += 1
        }
        XCTAssertEqual(undoCount, EditorSnapshot.maxHistoryDepth)
    }

    func testRepeatedUndoAndRedoReachStableState() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let originalRotation = page.rotation

        viewModel.rotatePage(id: page.id)
        viewModel.rotatePage(id: page.id)

        viewModel.undo()
        viewModel.undo()
        XCTAssertEqual(viewModel.pages.first(where: { $0.id == page.id })?.rotation, originalRotation)

        viewModel.redo()
        viewModel.redo()
        XCTAssertEqual(viewModel.pages.first(where: { $0.id == page.id })?.rotation, (originalRotation + 180) % 360)
    }

    func testHistoryRevisionIncrementsOnUndoAndRedo() throws {
        let revisionBefore = viewModel.historyRevision
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)

        viewModel.undo()
        XCTAssertEqual(viewModel.historyRevision, revisionBefore + 1)

        viewModel.redo()
        XCTAssertEqual(viewModel.historyRevision, revisionBefore + 2)
    }

    func testResolvedPageItemIDKeepsExistingPage() throws {
        let page = try XCTUnwrap(viewModel.pages[2])
        XCTAssertEqual(
            viewModel.resolvedPageItemID(currentID: page.id, preferredIndex: 2),
            page.id
        )
    }

    func testResolvedPageItemIDFallsBackWhenPageDeleted() throws {
        let page = try XCTUnwrap(viewModel.pages[2])
        let deletedID = page.id
        viewModel.deletePage(id: deletedID)

        let resolved = try XCTUnwrap(
            viewModel.resolvedPageItemID(currentID: deletedID, preferredIndex: 2)
        )
        XCTAssertNotEqual(resolved, deletedID)
        XCTAssertTrue(viewModel.pages.contains(where: { $0.id == resolved }))
    }

    // MARK: - Page operations

    func testRotatePageUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.first?.rotation, 0)

        viewModel.redo()
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)
    }

    func testDeletePageUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages[1])
        let pageID = page.id
        let countBefore = viewModel.pages.count

        viewModel.deletePage(id: pageID)
        XCTAssertEqual(viewModel.pages.count, countBefore - 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.count, countBefore)
        XCTAssertNotNil(viewModel.pages.first(where: { $0.id == pageID }))

        viewModel.redo()
        XCTAssertEqual(viewModel.pages.count, countBefore - 1)
        XCTAssertNil(viewModel.pages.first(where: { $0.id == pageID }))
    }

    func testDuplicatePageUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let countBefore = viewModel.pages.count

        viewModel.duplicatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.count, countBefore + 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.count, countBefore)

        viewModel.redo()
        XCTAssertEqual(viewModel.pages.count, countBefore + 1)
    }

    func testReorderPageUndoRedo() throws {
        let originalOrder = viewModel.pages.map(\.id)
        viewModel.recordUndoForDrag()
        viewModel.reorderPage(from: 0, to: 2)
        XCTAssertNotEqual(viewModel.pages.map(\.id), originalOrder)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.map(\.id), originalOrder)

        viewModel.redo()
        XCTAssertNotEqual(viewModel.pages.map(\.id), originalOrder)
    }

    // MARK: - Overlays

    func testAddImageOverlayUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)

        viewModel.redo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
    }

    func testMoveOverlayUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let originalPosition = overlay.position

        overlay.position = CGPoint(x: 0.15, y: 0.85)
        viewModel.updateOverlay(overlay)

        viewModel.undo()
        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.position.x, originalPosition.x, accuracy: 0.001)

        viewModel.redo()
        let redone = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(redone.position.x, 0.15, accuracy: 0.001)
    }

    func testDeleteOverlayUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let overlayID = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first?.id)

        viewModel.deleteOverlay(id: overlayID, pageItemID: page.id)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)

        viewModel.redo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
    }

    func testOverlayAssetSurvivesUndoRedoCycle() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let assetID = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first?.imageAssetID)
        let overlayID = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first?.id)

        viewModel.deleteOverlay(id: overlayID, pageItemID: page.id)
        viewModel.undo()
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))

        viewModel.redo()
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))
    }

    func testSignatureAppearanceUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            image: OverlayTestFactory.makeSignatureImage(),
            pageAspectRatio: 612.0 / 792.0,
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
            inkColor: .red,
            strokeWidthPoints: 6
        )

        viewModel.undo()
        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(restored.effectiveSignatureInkColor, .black)

        viewModel.redo()
        let redone = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(redone.effectiveSignatureInkColor, .red)
    }

    // MARK: - Annotations

    func testAddHighlightUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addHighlight(
            to: page.id,
            normalizedRects: [PageNormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.05)],
            selectedText: "Sample"
        )
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 0)

        viewModel.redo()
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 1)
    }

    func testStickyNoteMoveUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let noteID = try XCTUnwrap(
            viewModel.addStickyNote(
                to: page.id,
                normalizedPosition: PageNormalizedPoint(x: 0.3, y: 0.3),
                noteText: "Note"
            )
        )

        viewModel.moveStickyNote(
            id: noteID,
            pageItemID: page.id,
            normalizedPosition: PageNormalizedPoint(x: 0.7, y: 0.7)
        )

        viewModel.undo()
        let restored = try XCTUnwrap(viewModel.annotation(id: noteID, pageItemID: page.id))
        XCTAssertEqual(restored.normalizedPosition?.x ?? 0, 0.3, accuracy: 0.001)

        viewModel.redo()
        let redone = try XCTUnwrap(viewModel.annotation(id: noteID, pageItemID: page.id))
        XCTAssertEqual(redone.normalizedPosition?.x ?? 0, 0.7, accuracy: 0.001)
    }

    func testDrawingAnnotationUndoRedo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let stroke = DrawingStroke(
            normalizedPoints: [
                PageNormalizedPoint(x: 0.2, y: 0.2),
                PageNormalizedPoint(x: 0.4, y: 0.4)
            ],
            colorRGBA: DrawingPresetColor.black.rgba,
            normalizedLineWidth: Double(DrawingThicknessPreset.medium.normalizedWidth)
        )
        viewModel.addDrawingAnnotation(to: page.id, strokes: [stroke])
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 0)

        viewModel.redo()
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 1)
    }

    func testOverlayAndAnnotationExistenceHelpers() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        let highlightID = try XCTUnwrap(
            viewModel.addHighlight(
                to: page.id,
                normalizedRects: [PageNormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.03)],
                selectedText: "Test"
            )
        )

        XCTAssertTrue(viewModel.overlayExists(id: overlayID, pageItemID: page.id))
        XCTAssertTrue(viewModel.annotationExists(id: highlightID, pageItemID: page.id))

        viewModel.deleteOverlay(id: overlayID, pageItemID: page.id)
        viewModel.deleteAnnotation(id: highlightID, pageItemID: page.id)

        XCTAssertFalse(viewModel.overlayExists(id: overlayID, pageItemID: page.id))
        XCTAssertFalse(viewModel.annotationExists(id: highlightID, pageItemID: page.id))
    }

    // MARK: - Document-level

    func testApplyPageNumbersUndoRedo() throws {
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        settings.startNumber = 7
        viewModel.applyPageNumbers(settings)
        XCTAssertTrue(viewModel.pageNumberSettings.isEnabled)
        XCTAssertEqual(viewModel.pageNumberSettings.startNumber, 7)

        viewModel.undo()
        XCTAssertFalse(viewModel.pageNumberSettings.isEnabled)

        viewModel.redo()
        XCTAssertTrue(viewModel.pageNumberSettings.isEnabled)
        XCTAssertEqual(viewModel.pageNumberSettings.startNumber, 7)
    }

    func testRemovePageNumbersUndoRedo() throws {
        var settings = PageNumberSettings.default
        settings.isEnabled = true
        viewModel.applyPageNumbers(settings)
        viewModel.removePageNumbers()
        XCTAssertFalse(viewModel.pageNumberSettings.isEnabled)

        viewModel.undo()
        XCTAssertTrue(viewModel.pageNumberSettings.isEnabled)

        viewModel.redo()
        XCTAssertFalse(viewModel.pageNumberSettings.isEnabled)
    }

    func testTextWatermarkUndoRedo() throws {
        var settings = WatermarkSettings.default
        settings.text = "CONFIDENTIAL"
        viewModel.applyWatermark(settings)
        XCTAssertEqual(viewModel.watermarkSettings.text, "CONFIDENTIAL")

        viewModel.undo()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)

        viewModel.redo()
        XCTAssertEqual(viewModel.watermarkSettings.text, "CONFIDENTIAL")
    }

    func testImageWatermarkUndoRedo() throws {
        var settings = WatermarkSettings.default
        settings.watermarkType = .image
        let image = PDFTestFactory.makeTestImage(color: .blue)
        viewModel.applyWatermark(settings, watermarkImage: image)
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .image)
        let assetID = try XCTUnwrap(viewModel.watermarkSettings.imageAssetID)

        viewModel.removeWatermark()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)

        viewModel.undo()
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .image)
        XCTAssertNotNil(viewModel.imageAsset(for: assetID))

        viewModel.redo()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)
    }

    // MARK: - Export and source PDF

    func testExportAfterUndoReflectsUndoneState() async throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        viewModel.undo()

        let exportURL = try await viewModel.exportPDF()
        tempURLs.append(exportURL)

        let document = try XCTUnwrap(PDFDocument(url: exportURL))
        let exportedPage = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(Int(exportedPage.rotation), 0)
    }

    func testExportAfterRedoReflectsRedoneState() async throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        viewModel.undo()
        viewModel.redo()

        let exportURL = try await viewModel.exportPDF()
        tempURLs.append(exportURL)

        let document = try XCTUnwrap(PDFDocument(url: exportURL))
        let exportedPage = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(Int(exportedPage.rotation), 90)
    }

    func testUndoRedoDoNotMutateSourcePDF() throws {
        let importedBefore = try pdfService.importPDF(from: sourceURL)
        let pageCountBefore = importedBefore.document.pageCount

        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        viewModel.deletePage(id: page.id)
        viewModel.undo()
        viewModel.redo()

        let importedAfter = try pdfService.importPDF(from: sourceURL)
        XCTAssertEqual(importedAfter.document.pageCount, pageCountBefore)
    }
}
