import XCTest
@testable import pdfpagearranger

final class PDFAnnotationUIRegressionTests: XCTestCase {
    func testPageOverlayCanvasIncludesStickyNoteDragHandle() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageOverlayCanvasView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("stickyNoteDragHandle"))
        XCTAssertTrue(source.contains("accessibilityIdentifier(\"stickyNoteMarker\")"))
        XCTAssertTrue(source.contains("onMoveStickyNote"))
    }

    func testDrawingModeBlocksDocumentScrollWhenActive() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageEditorView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        // Unified document: drawing gestures take priority; vertical scroll is disabled while drawing.
        XCTAssertTrue(source.contains(".scrollDisabled(interactionBlockingScroll || textEditingActive || drawingModeActive"))
        XCTAssertTrue(source.contains("isUnifiedDocumentSurface || drawingModeActive || stickyNotePlacementActive"))
        // Horizontal page swipe remains nil on the unified surface (and while drawing / sticky placement).
        XCTAssertTrue(source.contains("? nil"))
        // Add is disabled during drawing so users finish the stroke session first.
        XCTAssertTrue(source.contains(".disabled(drawingModeActive)"))
    }

    func testAddSheetIncludesDrawAndStickyNoteOptions() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageAddOptionsSheet.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("\"addDrawOption\""))
        XCTAssertTrue(source.contains("\"addStickyNoteOption\""))
    }
}
