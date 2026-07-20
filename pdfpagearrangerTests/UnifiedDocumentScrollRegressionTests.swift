import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class UnifiedDocumentScrollRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.writePDF(
            named: "unified-document-scroll",
            pageCount: 4,
            labels: ["A", "B", "C", "D"]
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

    func testVerticalPageOrderingMatchesDocumentOrder() {
        XCTAssertEqual(viewModel.pageCount, 4)
        let ids = viewModel.pages.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        for (index, page) in viewModel.pages.enumerated() {
            XCTAssertEqual(viewModel.pageIndex(for: page.id), index)
        }
    }

    func testPrimaryPageDetectionPrefersActivationBandThenClosestCenter() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let primary = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [a: 40, b: 220, c: 480],
            viewportHeight: 400,
            fallback: a
        )
        XCTAssertEqual(primary, b)

        let onlyOutOfBand = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [a: 20, c: 390],
            viewportHeight: 400,
            fallback: a
        )
        XCTAssertEqual(onlyOutOfBand, a)
    }

    func testActivePageUpdateBlockedDuringEditingInteractions() {
        let current = UUID()
        let proposed = UUID()
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldUpdateActivePage(
                proposedID: proposed,
                currentID: current,
                interactionBlockingScroll: true
            )
        )
        XCTAssertTrue(
            DocumentScrollNavigationEngine.shouldUpdateActivePage(
                proposedID: proposed,
                currentID: current,
                interactionBlockingScroll: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldUpdateActivePage(
                proposedID: current,
                currentID: current,
                interactionBlockingScroll: false
            )
        )
    }

    func testResolvedActivePageAfterDeletion() {
        let pages = viewModel.pages
        let deletedIndex = 1
        let deleted = pages[deletedIndex].id
        let remaining = Array(pages.prefix(deletedIndex) + pages.suffix(from: deletedIndex + 1))
        let resolved = DocumentScrollNavigationEngine.resolvedActivePageID(
            preferredID: deleted,
            pages: remaining,
            preferredIndexAfterRemoval: deletedIndex
        )
        XCTAssertEqual(resolved, remaining[deletedIndex].id)
    }

    func testSinglePageDocumentKeepsSoleActivePage() async throws {
        let url = try PDFTestFactory.writePDF(named: "unified-one-page", pageCount: 1, labels: ["Only"])
        tempURLs.append(url)
        let single = PDFEditorViewModel()
        await single.importPDF(from: url)
        let id = try XCTUnwrap(single.pages.first?.id)
        let resolved = DocumentScrollNavigationEngine.resolvedActivePageID(
            preferredID: id,
            pages: single.pages
        )
        XCTAssertEqual(resolved, id)
    }

    func testPageInsertionDuplicationRotationAndReorderPreserveActiveSelection() throws {
        let original = try XCTUnwrap(viewModel.pages.first?.id)
        viewModel.rotatePage(id: original)
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)

        viewModel.duplicatePage(id: original)
        XCTAssertEqual(viewModel.pageCount, 5)
        XCTAssertEqual(viewModel.pages[1].rotation, 90)

        viewModel.reorderPage(from: 0, to: 2)
        XCTAssertTrue(viewModel.pages.contains(where: { $0.id == original }))
        let resolved = DocumentScrollNavigationEngine.resolvedActivePageID(
            preferredID: original,
            pages: viewModel.pages
        )
        XCTAssertEqual(resolved, original)
    }

    func testUnifiedSurfaceSourceGuards() throws {
        let editor = try source(named: "EditorView.swift")
        let pageEditor = try source(named: "PageEditorView.swift")
        let canvas = try source(named: "PageOverlayCanvasView.swift")

        XCTAssertTrue(editor.contains("isUnifiedDocumentSurface: true"))
        XCTAssertFalse(editor.contains("navigationDestination(item:"))
        XCTAssertTrue(editor.contains("DocumentPagesOrganizerSheet"))
        XCTAssertTrue(pageEditor.contains("unifiedDocumentScroll"))
        XCTAssertTrue(pageEditor.contains("DocumentScrollNavigationEngine"))
        XCTAssertTrue(pageEditor.contains("isUnifiedDocumentSurface || drawingModeActive"))
        XCTAssertTrue(pageEditor.contains("pageToolbarRotate"))
        XCTAssertTrue(pageEditor.contains("DocumentActionsMenu"))
        // Horizontal swipe retained in canvas for non-unified / editing contexts, but disabled on unified surface.
        XCTAssertTrue(canvas.contains("pageSwipeGesture"))
        XCTAssertTrue(pageEditor.contains("? nil"))
    }

    func testPageToolbarVersusDocumentMenuScope() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let menu = try source(named: "DocumentActionsMenu.swift")
        XCTAssertTrue(pageEditor.contains("pageModeAddButton"))
        XCTAssertTrue(pageEditor.contains("pageToolbarRotate"))
        XCTAssertTrue(pageEditor.contains("pageToolbarDuplicate"))
        XCTAssertTrue(pageEditor.contains("pageToolbarDelete"))
        XCTAssertTrue(menu.contains("organizePages"))
        XCTAssertTrue(menu.contains("compress"))
        XCTAssertTrue(menu.contains("export"))
    }

    func testScrollDisabledDuringTextAndDrawingInteractions() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains(".scrollDisabled(interactionBlockingScroll || textEditingActive || drawingModeActive"))
        XCTAssertTrue(pageEditor.contains("keyboardBottomInset"))
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
}
