import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFUndoComprehensiveRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .multiPage)
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

    func testUndoDeleteRestoresPageAndOverlays() throws {
        let page = viewModel.pages[1]
        _ = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)
        let overlayCountBefore = viewModel.overlayObjects(for: page.id).count
        let pageID = page.id

        viewModel.deletePage(id: pageID)
        XCTAssertEqual(viewModel.pages.count, 3)
        XCTAssertEqual(viewModel.overlayObjects(for: pageID).count, 0)

        viewModel.undo()

        XCTAssertEqual(viewModel.pages.count, 4)
        let restored = try XCTUnwrap(viewModel.pages.first(where: { $0.id == pageID }))
        XCTAssertEqual(viewModel.overlayObjects(for: restored.id).count, overlayCountBefore)
    }

    func testUndoRotateRestoresRotation() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.rotatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.first?.rotation, 0)
    }

    func testUndoReorderRestoresOrder() throws {
        let originalOrder = viewModel.pages.map(\.id)
        viewModel.recordUndoForDrag()
        viewModel.reorderPage(from: 0, to: 2)
        XCTAssertNotEqual(viewModel.pages.map(\.id), originalOrder)

        viewModel.undo()
        XCTAssertEqual(viewModel.pages.map(\.id), originalOrder)
    }

    func testUndoDuplicateAlreadyCoveredByExistingTests() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.duplicatePage(id: page.id)
        XCTAssertEqual(viewModel.pages.count, 5)
        viewModel.undo()
        XCTAssertEqual(viewModel.pages.count, 4)
    }
}
