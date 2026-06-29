import PDFKit
import XCTest
@testable import pdfpagearranger

final class DocumentThumbnailLayoutRegressionTests: XCTestCase {
    private let letterWidth: CGFloat = 612
    private let letterHeight: CGFloat = 792

    func testZeroDegreeThumbnailUsesPortraitStyleSizing() {
        XCTAssertEqual(PageThumbnailLayout.orientation(for: 0), .portraitStyle)

        let size = PageThumbnailLayout.displaySize(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 0
        )

        XCTAssertEqual(size.height, PageThumbnailLayout.standardPortraitHeight, accuracy: 0.001)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertLessThan(size.width, size.height)
    }

    func testOneEightyDegreeThumbnailUsesPortraitStyleSizing() {
        XCTAssertEqual(PageThumbnailLayout.orientation(for: 180), .portraitStyle)

        let size = PageThumbnailLayout.displaySize(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 180
        )

        XCTAssertEqual(size.height, PageThumbnailLayout.standardPortraitHeight, accuracy: 0.001)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertLessThan(size.width, size.height)
    }

    func testNinetyDegreeThumbnailUsesLandscapeStyleSizing() {
        XCTAssertEqual(PageThumbnailLayout.orientation(for: 90), .landscapeStyle)

        let size = PageThumbnailLayout.displaySize(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 90
        )

        XCTAssertEqual(size.width, PageThumbnailLayout.standardLandscapeWidth, accuracy: 0.001)
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(size.width, size.height)
    }

    func testTwoSeventyDegreeThumbnailUsesLandscapeStyleSizing() {
        XCTAssertEqual(PageThumbnailLayout.orientation(for: 270), .landscapeStyle)

        let size = PageThumbnailLayout.displaySize(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 270
        )

        XCTAssertEqual(size.width, PageThumbnailLayout.standardLandscapeWidth, accuracy: 0.001)
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(size.width, size.height)
    }

    func testRotatedPageThumbnailIsNotSignificantlySmallerThanPortraitThumbnail() {
        let portraitSize = PageThumbnailLayout.displaySize(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 0
        )
        let rotatedSize = PageThumbnailLayout.displaySize(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 90
        )

        let portraitArea = portraitSize.width * portraitSize.height
        let rotatedArea = rotatedSize.width * rotatedSize.height

        XCTAssertGreaterThan(rotatedArea, portraitArea * 0.85)
        XCTAssertGreaterThan(rotatedSize.width, portraitSize.width * 0.85)
    }

    func testDisplayAspectRatioUsesRotatedPageDimensions() {
        let portraitAspect = PageThumbnailLayout.displayAspectRatio(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 0
        )
        let landscapeAspect = PageThumbnailLayout.displayAspectRatio(
            pageWidth: letterWidth,
            pageHeight: letterHeight,
            rotation: 90
        )

        XCTAssertEqual(portraitAspect, letterWidth / letterHeight, accuracy: 0.001)
        XCTAssertEqual(landscapeAspect, letterHeight / letterWidth, accuracy: 0.001)
    }

    func testPageThumbnailViewUsesRotationAwareLayout() throws {
        let source = try TestSourceLoader.source(named: "PageThumbnailView.swift", subdirectory: "Views")
        XCTAssertTrue(source.contains("PageThumbnailLayout.orientation"))
        XCTAssertTrue(source.contains("PageThumbnailLayout.standardPortraitHeight"))
        XCTAssertTrue(source.contains("PageThumbnailLayout.standardLandscapeWidth"))
        XCTAssertFalse(source.contains("aspectRatio(0.72"))
    }

    func testExportRotationBehaviorRemainsUnchanged() throws {
        let exportSource = try TestSourceLoader.source(named: "PDFService.swift", subdirectory: "Services")
        XCTAssertTrue(exportSource.contains("sourcePage.rotation = 0"))
        XCTAssertTrue(exportSource.contains("page.rotation = pageRotation"))
        XCTAssertTrue(exportSource.contains("pageRotation: pageRotation"))
    }
}

private enum TestSourceLoader {
    static func source(named fileName: String, subdirectory: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("pdfpagearranger")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
