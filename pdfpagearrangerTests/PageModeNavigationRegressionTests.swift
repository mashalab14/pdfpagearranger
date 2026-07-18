import XCTest
@testable import pdfpagearranger

@MainActor
final class PageModeNavigationRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.writePDF(
            named: "page-mode-navigation",
            pageCount: 3,
            labels: ["A", "B", "C"]
        )
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

    private func source(named fileName: String, subdirectory: String = "Views") throws -> String {
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

    func testPageOverlayCanvasDefinesHorizontalPageSwipeGesture() throws {
        let source = try source(named: "PageOverlayCanvasView.swift")
        XCTAssertTrue(source.contains("pageSwipeGesture"))
        XCTAssertTrue(source.contains("PageModeNavigationEngine.direction"))
        XCTAssertTrue(source.contains("onPageSwipe"))
        XCTAssertTrue(source.contains("simultaneousGesture(pageSwipeEnabled ? pageSwipeGesture : nil)"))
    }

    func testOverlayDragUsesManipulationState() throws {
        let overlaySource = try source(named: "ImageOverlayObjectView.swift")
        XCTAssertTrue(overlaySource.contains("dragGesture"))
        XCTAssertTrue(overlaySource.contains("manipulationState.begin()"))
        XCTAssertTrue(overlaySource.contains("isSelected && isInteractionEnabled ? dragGesture : nil"))
    }

    func testOverlayManipulationBlocksPageSwipe() throws {
        let canvasSource = try source(named: "PageOverlayCanvasView.swift")
        XCTAssertTrue(canvasSource.contains("overlayManipulationState"))
        XCTAssertTrue(canvasSource.contains("PageModeNavigationEngine.shouldAllowPageSwipe"))

        let overlaySource = try source(named: "ImageOverlayObjectView.swift")
        XCTAssertTrue(overlaySource.contains("manipulationState.begin()"))
        XCTAssertTrue(overlaySource.contains("manipulationState.end()"))
        XCTAssertTrue(overlaySource.contains("highPriorityGesture(resizeHandleGesture)"))
    }

    func testPinchGesturesRemainAvailable() throws {
        let canvasSource = try source(named: "PageOverlayCanvasView.swift")
        XCTAssertTrue(canvasSource.contains("MagnificationGesture()"))

        let overlaySource = try source(named: "ImageOverlayObjectView.swift")
        XCTAssertTrue(overlaySource.contains("simultaneousGesture(isSelected && isInteractionEnabled ? magnificationGesture : nil)"))
    }

    func testPageEditorNavigatesByUpdatingPageRoute() throws {
        let source = try source(named: "PageEditorView.swift")
        XCTAssertTrue(source.contains("navigateToAdjacentPage"))
        XCTAssertTrue(source.contains("PageModeNavigationEngine.adjacentPageIndex"))
        XCTAssertTrue(source.contains("pageSelection = .none"))
        XCTAssertTrue(source.contains("isUnifiedDocumentSurface"))
        XCTAssertTrue(source.contains("unifiedDocumentScroll"))
        XCTAssertTrue(source.contains("isUnifiedDocumentSurface || drawingModeActive || stickyNotePlacementActive"))
    }

    func testOverlayStateRemainsCorrectPerPage() throws {
        let firstPage = try XCTUnwrap(viewModel.pages.first)
        let secondPage = try XCTUnwrap(viewModel.pages.dropFirst().first)

        viewModel.addImageOverlay(
            to: firstPage.id,
            image: PDFTestFactory.makeTestImage(color: .red),
            pageAspectRatio: 0.77
        )
        viewModel.addImageOverlay(
            to: secondPage.id,
            image: PDFTestFactory.makeTestImage(color: .blue),
            pageAspectRatio: 0.77
        )

        XCTAssertEqual(viewModel.overlayObjects(for: firstPage.id).count, 1)
        XCTAssertEqual(viewModel.overlayObjects(for: secondPage.id).count, 1)
        XCTAssertNotEqual(
            viewModel.overlayObjects(for: firstPage.id).first?.imageAssetID,
            viewModel.overlayObjects(for: secondPage.id).first?.imageAssetID
        )
    }

    func testUndoHistoryRemainsValidAfterNavigationScenario() throws {
        let firstPage = try XCTUnwrap(viewModel.pages.first)
        let undoDepthBefore = viewModel.canUndo

        viewModel.addImageOverlay(
            to: firstPage.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 0.77
        )
        XCTAssertTrue(viewModel.canUndo)

        let secondPage = try XCTUnwrap(viewModel.pages.dropFirst().first)
        XCTAssertTrue(viewModel.overlayObjects(for: secondPage.id).isEmpty)

        viewModel.undo()
        XCTAssertEqual(viewModel.canUndo, undoDepthBefore)
        XCTAssertTrue(viewModel.overlayObjects(for: firstPage.id).isEmpty)
    }
}
