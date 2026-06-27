import PDFKit
import XCTest
@testable import pdfpagearranger

final class PDFThumbnailRegressionTests: XCTestCase {
    private var tempURLs: [URL] = []

    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        super.tearDown()
    }

    func testPreviewRendererPreservesTopBottomOrientation() throws {
        let probeURL = try PDFTestFactory.makeOrientationProbePDF()
        tempURLs.append(probeURL)

        let document = try XCTUnwrap(PDFDocument(url: probeURL))
        let page = try XCTUnwrap(document.page(at: 0))

        let image = try XCTUnwrap(
            PDFPreviewRenderer.image(from: page, rotation: 0, maxDimension: 300, maxScale: 1.0)
        )

        let size = image.size
        let topColor = try XCTUnwrap(ImageTestHelpers.averageColor(
            in: image,
            rect: CGRect(x: size.width * 0.25, y: size.height * 0.05, width: size.width * 0.5, height: size.height * 0.15)
        ))
        let bottomColor = try XCTUnwrap(ImageTestHelpers.averageColor(
            in: image,
            rect: CGRect(x: size.width * 0.25, y: size.height * 0.8, width: size.width * 0.5, height: size.height * 0.15)
        ))

        XCTAssertTrue(ImageTestHelpers.isMostlyRed(topColor), "Top of thumbnail should remain red (not upside-down)")
        XCTAssertTrue(ImageTestHelpers.isMostlyBlue(bottomColor), "Bottom of thumbnail should remain blue (not upside-down)")
    }

    func testThumbnailServiceIncludesOverlayComposite() async throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        let pageItem = PageItem(originalPageIndex: 0)
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(
            pageItemID: pageItem.id,
            assetID: assetID,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.4, height: 0.4)
        )
        let greenImage = PDFTestFactory.makeTestImage(color: .green, size: CGSize(width: 40, height: 40))

        let withoutOverlay = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [],
            overlayImages: [:],
            revision: 0
        )
        let withOverlay = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [overlay],
            overlayImages: [assetID: greenImage],
            revision: 1
        )

        let base = try XCTUnwrap(withoutOverlay)
        let composited = try XCTUnwrap(withOverlay)
        XCTAssertNotEqual(base.pngData(), composited.pngData(), "Overlay should change thumbnail output")

        let centerColor = try XCTUnwrap(ImageTestHelpers.averageColor(
            in: composited,
            rect: CGRect(
                x: composited.size.width * 0.4,
                y: composited.size.height * 0.4,
                width: composited.size.width * 0.2,
                height: composited.size.height * 0.2
            )
        ))
        XCTAssertTrue(ImageTestHelpers.isMostlyGreen(centerColor))
    }

    func testThumbnailRevisionKeyChangesWhenOverlayAdded() async throws {
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        let pageItem = PageItem(originalPageIndex: 0)

        let revision0 = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [],
            overlayImages: [:],
            revision: 0
        )
        let revision1 = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [],
            overlayImages: [:],
            revision: 1
        )

        XCTAssertNotNil(revision0)
        XCTAssertNotNil(revision1)
    }

    func testRotatedSourcePageRendersWithoutMirroring() throws {
        let sourceURL = try PDFTestFactory.url(for: .rotatedPages)
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(page.rotation, 90)

        let image = try XCTUnwrap(
            PDFPreviewRenderer.image(from: page, rotation: 0, maxDimension: 200, maxScale: 1.0)
        )
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}
