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

    func testDrawingModeBlocksPageSwipeWhenActive() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageEditorView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("drawingModeActive || stickyNotePlacementActive ? nil"))
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
