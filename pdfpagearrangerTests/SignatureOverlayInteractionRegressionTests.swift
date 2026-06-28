import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class SignatureOverlayInteractionRegressionTests: XCTestCase {
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

    private func imageOverlaySource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/ImageOverlayObjectView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testOverlayDragCapturesStartCenterBeforeApplyingTranslation() throws {
        let source = try imageOverlaySource()
        XCTAssertTrue(source.contains("dragOriginCenter"))
        XCTAssertTrue(source.contains("DragGesture(minimumDistance: 0)"))
        XCTAssertTrue(source.contains("OverlayInteractionEngine.dragDisplayCenter"))
    }

    func testOverlayResizeHandleIsWiredForDragResize() throws {
        let source = try imageOverlaySource()
        XCTAssertTrue(source.contains("overlayResizeHandle"))
        XCTAssertTrue(source.contains("resizeHandleGesture"))
        XCTAssertTrue(source.contains("OverlayInteractionEngine.uniformResizedLayoutSize"))
    }

    func testOverlayImageUsesContentShapeForReliableHitTesting() throws {
        let source = try imageOverlaySource()
        XCTAssertTrue(source.contains(".contentShape(Rectangle())"))
    }

    func testPinchResizeRemainsAvailable() throws {
        let source = try imageOverlaySource()
        XCTAssertTrue(source.contains("MagnificationGesture()"))
        XCTAssertTrue(source.contains("OverlayInteractionEngine.magnificationResizedNormalizedSize"))
    }

    func testUndoWorksAfterSignatureMove() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        var moved = signature
        moved.position = CGPoint(x: 0.35, y: 0.65)
        viewModel.updateOverlay(moved)

        let updated = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(updated.position.x, 0.35, accuracy: 0.001)

        viewModel.undo()
        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.position.x, signature.position.x, accuracy: 0.001)
    }

    func testUndoWorksAfterSignatureResize() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        var resized = signature
        resized.size = CGSize(width: 0.45, height: 0.18)
        viewModel.updateOverlay(resized)

        let updated = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(updated.size.width, 0.45, accuracy: 0.001)

        viewModel.undo()
        let restored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(restored.size.width, signature.size.width, accuracy: 0.001)
    }

    func testExportPreservesResizedSignature() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        var resized = signature
        resized.size = CGSize(width: 0.42, height: 0.16)
        viewModel.updateOverlay(resized)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(1, in: exportURL)
        XCTAssertNotNil(PDFDocument(url: exportURL)?.page(at: 0))
    }

    func testDuplicatePagePreservesResizedSignature() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        var resized = signature
        resized.size = CGSize(width: 0.4, height: 0.15)
        viewModel.updateOverlay(resized)

        viewModel.duplicatePage(id: page.id)

        let duplicatePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id != page.id }))
        let copied = try XCTUnwrap(viewModel.overlayObjects(for: duplicatePage.id).first)

        XCTAssertEqual(copied.size.width, 0.4, accuracy: 0.001)
        XCTAssertEqual(copied.size.height, 0.15, accuracy: 0.001)
    }
}
