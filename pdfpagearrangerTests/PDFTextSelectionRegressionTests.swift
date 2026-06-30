import CoreGraphics
import PDFKit
import XCTest
@testable import pdfpagearranger

final class PageModeSelectionModelTests: XCTestCase {
    func testSelectionStatesAreDistinct() {
        let overlayID = UUID()
        XCTAssertNil(PageModeSelection.none.selectedOverlayID)
        XCTAssertNil(PageModeSelection.none.pdfTextSelection)
        XCTAssertEqual(PageModeSelection.overlay(overlayID).selectedOverlayID, overlayID)
        XCTAssertEqual(
            PageModeSelection.pdfText(PDFTextSelection(text: "A", anchorRect: .zero)).pdfTextSelection?.text,
            "A"
        )
    }
}

final class PDFTextSelectionEngineRegressionTests: XCTestCase {
    func testAnchorRectMapsPDFCoordinatesToDisplaySpace() throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "text-selection-anchor", text: "AnchorText")
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        let page = try XCTUnwrap(document.page(at: 0))
        let pageCopy = try XCTUnwrap(page.copy() as? PDFPage)

        let selection = try XCTUnwrap(pageCopy.selection(for: CGRect(x: 72, y: 700, width: 200, height: 40)))
        let displaySize = CGSize(width: 300, height: 400)

        let anchorRect = try XCTUnwrap(
            PDFTextSelectionEngine.anchorRect(
                for: selection,
                page: pageCopy,
                displaySize: displaySize
            )
        )

        XCTAssertGreaterThan(anchorRect.width, 0)
        XCTAssertGreaterThan(anchorRect.height, 0)
        XCTAssertGreaterThanOrEqual(anchorRect.minX, 0)
        XCTAssertLessThanOrEqual(anchorRect.maxX, displaySize.width)

        let textSelection = try XCTUnwrap(
            PDFTextSelectionEngine.makeTextSelection(
                from: selection,
                page: pageCopy,
                displaySize: displaySize
            )
        )
        XCTAssertTrue(textSelection.text.contains("Anchor"))
    }

    func testClampNormalizedCenterKeepsOverlayInsidePage() {
        let center = OverlayInteractionEngine.clampNormalizedCenter(
            CGPoint(x: 0, y: 0),
            normalizedSize: CGSize(width: 0.4, height: 0.2)
        )
        XCTAssertEqual(center.x, 0.2, accuracy: 0.001)
        XCTAssertEqual(center.y, 0.1, accuracy: 0.001)
    }
}

final class PDFTextSelectionUIRegressionTests: XCTestCase {
    func testPageModeUsesUnifiedSelectionState() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("pageSelection: PageModeSelection = .none"))
        XCTAssertTrue(source.contains(".overlay("))
        XCTAssertTrue(source.contains("pdfSelectionClearToken"))
    }

    func testCanvasLayersPDFTextSelectionUnderPreviewImage() throws {
        let source = try canvasSource()
        XCTAssertTrue(source.contains("PDFPageTextSelectionView"))
        XCTAssertTrue(source.contains("pdfTextSelectionLayer"))
        XCTAssertTrue(source.contains("pdfTextSelectionLayerActive"))
        XCTAssertTrue(source.contains("onLongPressGesture"))
        XCTAssertTrue(source.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(source.contains("PDFTextSelectionContextMenu"))
    }

    func testContextMenuShowsPlaceholderActions() throws {
        let source = try menuSource()
        XCTAssertTrue(source.contains("Copy"))
        XCTAssertTrue(source.contains("Highlight"))
        XCTAssertTrue(source.contains("Comment"))
        XCTAssertTrue(source.contains("chevron.right"))
        XCTAssertTrue(source.contains("pdfTextMenuMore"))
        XCTAssertFalse(source.contains("\"More\""))
    }

    func testCopyUsesPasteboard() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("UIPasteboard.general.string"))
        XCTAssertTrue(source.contains("copySelectedPDFText"))
    }

    func testSignaturePlacementClearsPDFTextSelection() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("clearPDFTextSelection()"))
        XCTAssertTrue(source.contains("beginSignaturePlacement"))
    }

    func testOverlaySelectionReplacesPDFTextSelection() throws {
        let source = try canvasSource()
        XCTAssertTrue(source.contains("pageSelection = .overlay(object.id)"))
        XCTAssertTrue(source.contains("deactivatePDFTextSelectionLayer()"))
    }

    func testPDFSelectionLayerDoesNotEnablePageScrolling() throws {
        let source = try projectSource(named: "PDFPageTextSelectionView.swift", subdirectory: "Views")
        XCTAssertTrue(source.contains("NonScrollingPDFTextSelectionView"))
        XCTAssertTrue(source.contains("disableInternalScrolling"))
        XCTAssertTrue(source.contains("panGestureRecognizer.isEnabled = false"))
        XCTAssertTrue(source.contains("UISwipeGestureRecognizer"))
        XCTAssertTrue(source.contains("pageSwipeEnabled"))
    }

    private func pageEditorSource() throws -> String {
        try projectSource(named: "PageEditorView.swift", subdirectory: "Views")
    }

    private func canvasSource() throws -> String {
        try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
    }

    private func menuSource() throws -> String {
        try projectSource(named: "PDFTextSelectionContextMenu.swift", subdirectory: "Views")
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
