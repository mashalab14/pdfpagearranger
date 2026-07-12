import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFAnnotationRegressionTests: XCTestCase {
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

    // MARK: - Model and geometry

    func testMultiLineHighlightStoresMultipleNormalizedRects() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let rects = [
            PageNormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05),
            PageNormalizedRect(x: 0.1, y: 0.18, width: 0.6, height: 0.05)
        ]

        let highlightID = try XCTUnwrap(
            viewModel.addHighlight(to: page.id, normalizedRects: rects, selectedText: "Line one\nLine two")
        )
        let highlight = try XCTUnwrap(viewModel.annotation(id: highlightID, pageItemID: page.id))

        XCTAssertEqual(highlight.normalizedRects?.count, 2)
        XCTAssertEqual(highlight.normalizedRects?[0].y ?? 0, 0.1, accuracy: 0.001)
        XCTAssertEqual(highlight.normalizedRects?[1].y ?? 0, 0.18, accuracy: 0.001)
    }

    func testHighlightDisplayGeometryUnderPageRotation() {
        let storageRect = PageNormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05)
        let renderSize = CGSize(width: 400, height: 600)

        for rotation in [0, 90, 180, 270] {
            let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: rotation)
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: displayRect,
                renderSize: renderSize,
                coordinateSpace: .topLeftOrigin
            )
            XCTAssertGreaterThan(pixelRect.width, 0, "Rotation \(rotation)")
            XCTAssertGreaterThan(pixelRect.height, 0, "Rotation \(rotation)")
            XCTAssertTrue(pixelRect.maxX <= renderSize.width + 1, "Rotation \(rotation)")
            XCTAssertTrue(pixelRect.maxY <= renderSize.height + 1, "Rotation \(rotation)")
        }
    }

    func testDrawingStrokeUsesNormalizedPageRelativePoints() throws {
        var points: [PageNormalizedPoint] = []
        let pageSize = CGSize(width: 300, height: 400)
        DrawingStrokeBuilder.appendPoint(
            displayPoint: CGPoint(x: 30, y: 40),
            displayPageSize: pageSize,
            pageRotation: 0,
            to: &points
        )
        DrawingStrokeBuilder.appendPoint(
            displayPoint: CGPoint(x: 90, y: 120),
            displayPageSize: pageSize,
            pageRotation: 0,
            to: &points
        )

        let stroke = try XCTUnwrap(
            DrawingStrokeBuilder.makeStroke(from: points, color: .black, thickness: .medium)
        )

        XCTAssertEqual(stroke.normalizedPoints.count, 2)
        XCTAssertEqual(stroke.normalizedPoints[0].x, 0.1, accuracy: 0.001)
        XCTAssertEqual(stroke.normalizedPoints[0].y, 0.1, accuracy: 0.001)
        XCTAssertGreaterThan(stroke.normalizedLineWidth, 0)
        XCTAssertLessThan(stroke.normalizedLineWidth, 0.02)
    }

    func testStickyNotePositionClampsInsidePageBounds() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let noteID = try XCTUnwrap(
            viewModel.addStickyNote(
                to: page.id,
                normalizedPosition: PageNormalizedPoint(x: 1.2, y: -0.1),
                noteText: "Edge note"
            )
        )

        let note = try XCTUnwrap(viewModel.annotation(id: noteID, pageItemID: page.id))
        let position = try XCTUnwrap(note.normalizedPosition)
        XCTAssertGreaterThanOrEqual(position.x, 0)
        XCTAssertLessThanOrEqual(position.x, 1)
        XCTAssertGreaterThanOrEqual(position.y, 0)
        XCTAssertLessThanOrEqual(position.y, 1)
    }

    func testTextCommentPreservesAnchorGeometry() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let rects = [PageNormalizedRect(x: 0.2, y: 0.3, width: 0.5, height: 0.04)]
        let commentID = try XCTUnwrap(
            viewModel.addTextComment(
                to: page.id,
                normalizedRects: rects,
                selectedText: "Selected clause",
                commentText: "Needs review"
            )
        )

        let comment = try XCTUnwrap(viewModel.annotation(id: commentID, pageItemID: page.id))
        XCTAssertEqual(comment.normalizedRects?.count, 1)
        XCTAssertEqual(comment.selectedText, "Selected clause")
        XCTAssertEqual(comment.commentText, "Needs review")
    }

    func testDuplicatePageCreatesNewAnnotationIDs() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let highlightID = try XCTUnwrap(
            viewModel.addHighlight(
                to: page.id,
                normalizedRects: [PageNormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.05)],
                selectedText: "Sample"
            )
        )
        viewModel.duplicatePage(id: page.id)

        let duplicatePage = try XCTUnwrap(viewModel.pages.dropFirst().first)
        let sourceAnnotations = viewModel.annotations(for: page.id)
        let duplicateAnnotations = viewModel.annotations(for: duplicatePage.id)

        XCTAssertEqual(sourceAnnotations.count, 1)
        XCTAssertEqual(duplicateAnnotations.count, 1)
        XCTAssertNotEqual(sourceAnnotations[0].id, duplicateAnnotations[0].id)
        XCTAssertNotEqual(highlightID, duplicateAnnotations[0].id)
        XCTAssertEqual(
            sourceAnnotations[0].normalizedRects?[0].x ?? 0,
            duplicateAnnotations[0].normalizedRects?[0].x ?? 0,
            accuracy: 0.001
        )
    }

    func testDeletePageRemovesAnnotationsUndoRestores() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        _ = viewModel.addStickyNote(
            to: page.id,
            normalizedPosition: PageNormalizedPoint(x: 0.5, y: 0.5),
            noteText: "Temporary"
        )
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 1)

        viewModel.deletePage(id: page.id)
        XCTAssertTrue(viewModel.pages.isEmpty)

        viewModel.undo()
        let restoredPage = try XCTUnwrap(viewModel.pages.first)
        XCTAssertEqual(viewModel.annotations(for: restoredPage.id).count, 1)
    }

    func testUndoRestoresAnnotationSnapshot() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        _ = viewModel.addHighlight(
            to: page.id,
            normalizedRects: [PageNormalizedRect(x: 0.2, y: 0.2, width: 0.3, height: 0.04)],
            selectedText: "Undo me"
        )
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 1)

        viewModel.undo()
        XCTAssertEqual(viewModel.annotations(for: page.id).count, 0)
    }

    // MARK: - Undo behaviour

    func testUndoHighlightColorChangeAndDelete() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let highlightID = try XCTUnwrap(
            viewModel.addHighlight(
                to: page.id,
                normalizedRects: [PageNormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.05)],
                selectedText: "Color test"
            )
        )

        XCTAssertTrue(viewModel.updateHighlightColor(id: highlightID, pageItemID: page.id, color: .blue))
        XCTAssertEqual(
            viewModel.annotation(id: highlightID, pageItemID: page.id)?.highlightColor,
            .blue
        )

        viewModel.undo()
        XCTAssertEqual(
            viewModel.annotation(id: highlightID, pageItemID: page.id)?.highlightColor,
            .yellow
        )

        viewModel.deleteAnnotation(id: highlightID, pageItemID: page.id)
        XCTAssertNil(viewModel.annotation(id: highlightID, pageItemID: page.id))

        viewModel.undo()
        XCTAssertNotNil(viewModel.annotation(id: highlightID, pageItemID: page.id))
    }

    func testMoveStickyNoteUndoRestoresPosition() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let noteID = try XCTUnwrap(
            viewModel.addStickyNote(
                to: page.id,
                normalizedPosition: PageNormalizedPoint(x: 0.3, y: 0.4),
                noteText: "Move me"
            )
        )
        let original = try XCTUnwrap(viewModel.annotation(id: noteID, pageItemID: page.id).flatMap(\.normalizedPosition))

        XCTAssertTrue(
            viewModel.moveStickyNote(
                id: noteID,
                pageItemID: page.id,
                normalizedPosition: PageNormalizedPoint(x: 0.7, y: 0.6)
            )
        )
        let moved = try XCTUnwrap(viewModel.annotation(id: noteID, pageItemID: page.id).flatMap(\.normalizedPosition))
        XCTAssertNotEqual(moved.x, original.x, accuracy: 0.001)

        viewModel.undo()
        let restored = try XCTUnwrap(viewModel.annotation(id: noteID, pageItemID: page.id).flatMap(\.normalizedPosition))
        XCTAssertEqual(restored.x, original.x, accuracy: 0.001)
        XCTAssertEqual(restored.y, original.y, accuracy: 0.001)
    }

    // MARK: - Rendering and export

    func testExportIncludesAnnotationsAndPreservesSelectableText() throws {
        let expectedText = "SelectableAnnotationText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "AnnotationExport", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let highlight = PageAnnotation(
            pageItemID: page.id,
            kind: .highlight,
            normalizedRects: [PageNormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.08)],
            selectedText: expectedText,
            highlightColor: .yellow,
            highlightOpacity: 0.35
        )
        let drawing = PageAnnotation(
            pageItemID: page.id,
            kind: .drawing,
            strokes: [
                DrawingStroke(
                    normalizedPoints: [
                        PageNormalizedPoint(x: 0.2, y: 0.5),
                        PageNormalizedPoint(x: 0.8, y: 0.55)
                    ],
                    colorRGBA: DrawingPresetColor.red.rgba,
                    normalizedLineWidth: Double(DrawingThicknessPreset.medium.normalizedWidth)
                )
            ]
        )
        let stickyNote = PageAnnotation(
            pageItemID: page.id,
            kind: .stickyNote,
            normalizedPosition: PageNormalizedPoint(x: 0.85, y: 0.15),
            noteText: "Note",
            noteColorRGBA: StickyNoteStyle.defaultColor
        )
        let comment = PageAnnotation(
            pageItemID: page.id,
            kind: .textComment,
            normalizedRects: [PageNormalizedRect(x: 0.1, y: 0.2, width: 0.5, height: 0.04)],
            selectedText: "clause",
            commentText: "Question",
            anchorColorRGBA: TextCommentStyle.defaultAnchorColor
        )

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "annotation-export",
            annotationsByPage: [
                page.id: [highlight, drawing, stickyNote, comment]
            ]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(1, in: exportURL)
        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testThumbnailCompositesAnnotations() async throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        let pageItem = PageItem(originalPageIndex: 0)
        let highlight = PageAnnotation(
            pageItemID: pageItem.id,
            kind: .highlight,
            normalizedRects: [PageNormalizedRect(x: 0.2, y: 0.2, width: 0.6, height: 0.2)],
            selectedText: "Marked",
            highlightColor: .yellow,
            highlightOpacity: 0.8
        )

        let withoutAnnotation = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [],
            annotations: [],
            overlayImages: [:],
            revision: 0
        )
        let withAnnotation = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [],
            annotations: [highlight],
            overlayImages: [:],
            revision: 1
        )

        let base = try XCTUnwrap(withoutAnnotation)
        let composited = try XCTUnwrap(withAnnotation)
        XCTAssertNotEqual(base.pngData(), composited.pngData())
    }

    func testHighlightGeometryRoundTripAcrossRotations() {
        let storageRect = PageNormalizedRect(x: 0.2, y: 0.3, width: 0.4, height: 0.06)

        for rotation in [0, 90, 180, 270] {
            let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: rotation)
            let restored = AnnotationGeometryEngine.storageRect(from: displayRect, pageRotation: rotation)
            XCTAssertEqual(restored.x, storageRect.x, accuracy: 0.001, "Rotation \(rotation)")
            XCTAssertEqual(restored.y, storageRect.y, accuracy: 0.001, "Rotation \(rotation)")
            XCTAssertEqual(restored.width, storageRect.width, accuracy: 0.001, "Rotation \(rotation)")
            XCTAssertEqual(restored.height, storageRect.height, accuracy: 0.001, "Rotation \(rotation)")
        }
    }

    func testStoredCoordinatesUnchangedWhenPageRotated() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let rects = [PageNormalizedRect(x: 0.15, y: 0.25, width: 0.4, height: 0.05)]
        let highlightID = try XCTUnwrap(
            viewModel.addHighlight(to: page.id, normalizedRects: rects, selectedText: "Rotate")
        )

        viewModel.rotatePage(id: page.id)

        let highlight = try XCTUnwrap(viewModel.annotation(id: highlightID, pageItemID: page.id))
        XCTAssertEqual(highlight.normalizedRects?[0].x ?? 0, 0.15, accuracy: 0.001)
        XCTAssertEqual(highlight.normalizedRects?[0].y ?? 0, 0.25, accuracy: 0.001)
    }
}
