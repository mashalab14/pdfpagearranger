import PDFKit
import XCTest
@testable import pdfpagearranger

final class OverlayRotationRegressionTests: XCTestCase {
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []

    override func setUp() {
        super.setUp()
        pdfService = PDFService()
    }

    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        pdfService = nil
        super.tearDown()
    }

    func testRotatedPageThumbnailPlacesOverlayInTransformedLocation() async throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))

        let pageItem = PageItem(originalPageIndex: 0, rotation: 90)
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(
            pageItemID: pageItem.id,
            assetID: assetID,
            position: CGPoint(x: 0.9, y: 0.1),
            size: CGSize(width: 0.2, height: 0.2)
        )
        let greenImage = PDFTestFactory.makeTestImage(color: .green, size: CGSize(width: 40, height: 40))

        let thumbnail = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [overlay],
            annotations: [],
            overlayImages: [assetID: greenImage],
            revision: 1
        )
        let rendered = try XCTUnwrap(thumbnail)
        let size = rendered.size
        let bottomRight = try XCTUnwrap(ImageTestHelpers.averageColor(
            in: rendered,
            rect: CGRect(
                x: size.width * 0.75,
                y: size.height * 0.75,
                width: size.width * 0.15,
                height: size.height * 0.15
            )
        ))
        XCTAssertTrue(
            ImageTestHelpers.isMostlyGreen(bottomRight),
            "Overlay at stored top-right should appear at bottom-right when page is rotated 90°"
        )
    }

    func testCompositorUsesPageRotationWhenDrawingOverlays() throws {
        let baseImage = try XCTUnwrap(
            PDFPreviewRenderer.image(
                from: XCTUnwrap(PDFDocument(url: try PDFTestFactory.url(for: .onePage))?.page(at: 0)),
                rotation: 90,
                maxDimension: 200,
                maxScale: 1.0
            )
        )

        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(
            pageItemID: UUID(),
            assetID: assetID,
            position: CGPoint(x: 0.9, y: 0.1),
            size: CGSize(width: 0.25, height: 0.25)
        )
        let image = PDFTestFactory.makeTestImage(color: .green)

        let withoutRotation = OverlayCompositor.composite(
            baseImage: baseImage,
            objects: [overlay],
            images: [assetID: image],
            pageRotation: 0
        )
        let withRotation = OverlayCompositor.composite(
            baseImage: baseImage,
            objects: [overlay],
            images: [assetID: image],
            pageRotation: 90
        )

        XCTAssertNotEqual(withoutRotation.pngData(), withRotation.pngData())
    }

    func testExportRotatedPageWithOverlayPreservesSearchableText() throws {
        let expectedText = "RotatedOverlayExportText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-overlay-text", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(
            pageItemID: page.id,
            assetID: assetID,
            position: CGPoint(x: 0.9, y: 0.1)
        )

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "rotated-overlay-export",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage(color: .green)]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(1, in: exportURL)
        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        XCTAssertEqual(PDFDocument(url: exportURL)?.page(at: 0)?.rotation, 90)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testExportRotatedPageWithOverlayCompletesAndPreservesRotation() throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)

        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(
            pageItemID: page.id,
            assetID: assetID,
            position: CGPoint(x: 0.9, y: 0.1)
        )

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "rotated-overlay-export",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage(color: .green)]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(1, in: exportURL)
        XCTAssertNotNil(PDFDocument(url: exportURL)?.page(at: 0))
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    @MainActor
    func testDuplicatePageWithOverlayAfterRotationCopiesStoredGeometry() async throws {
        let viewModel = PDFEditorViewModel()
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        await viewModel.importPDF(from: sourceURL)

        let page = try XCTUnwrap(viewModel.pages.first)
        var overlay = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)
        overlay.position = CGPoint(x: 0.8, y: 0.2)
        viewModel.updateOverlay(overlay)
        viewModel.rotatePage(id: page.id)
        viewModel.duplicatePage(id: page.id)

        let sourcePage = try XCTUnwrap(viewModel.pages.first(where: { $0.id == page.id }))
        let duplicate = try XCTUnwrap(viewModel.pages.first(where: { $0.id != page.id }))
        XCTAssertEqual(duplicate.rotation, sourcePage.rotation)
        XCTAssertEqual(viewModel.overlayObjects(for: duplicate.id).count, 1)
        XCTAssertEqual(
            viewModel.overlayObjects(for: duplicate.id).first?.position,
            viewModel.overlayObjects(for: sourcePage.id).first?.position
        )
    }

    @MainActor
    func testRotatePageBumpsOverlayRevision() async throws {
        let viewModel = PDFEditorViewModel()
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        await viewModel.importPDF(from: sourceURL)

        let page = try XCTUnwrap(viewModel.pages.first)
        _ = OverlayTestFactory.seedOverlay(on: viewModel, pageItemID: page.id)
        let revisionBefore = viewModel.overlayRevision(for: page.id)

        viewModel.rotatePage(id: page.id)

        XCTAssertEqual(viewModel.overlayRevision(for: page.id), revisionBefore + 1)
        XCTAssertEqual(viewModel.pages.first?.rotation, 90)
    }
}
