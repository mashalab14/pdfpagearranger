import XCTest
@testable import pdfpagearranger

final class PageModeLayoutSizingTests: XCTestCase {
    private let portraitPageImage = CGSize(width: 612, height: 792)
    private let landscapePageImage = CGSize(width: 792, height: 612)

    func testAvailableWidthSubtractsSafeAreaAndMargins() {
        XCTAssertEqual(
            PageModeLayoutSizing.availableContentWidth(
                containerWidth: 393,
                leadingSafeAreaInset: 0,
                trailingSafeAreaInset: 0
            ),
            369,
            accuracy: 0.001
        )

        XCTAssertEqual(
            PageModeLayoutSizing.availableContentWidth(
                containerWidth: 844,
                leadingSafeAreaInset: 47,
                trailingSafeAreaInset: 47
            ),
            726,
            accuracy: 0.001
        )
    }

    func testDisplaySizeFillsAvailableWidthExactly() {
        let size = PageModeLayoutSizing.displaySize(
            imageSize: portraitPageImage,
            availableWidth: 369
        )

        XCTAssertEqual(size.width, 369, accuracy: 0.001)
    }

    func testDisplaySizePreservesAspectRatio() {
        let container = CGSize(width: 393, height: 700)
        let size = PageModeLayoutSizing.displaySize(
            imageSize: portraitPageImage,
            containerSize: container
        )

        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: portraitPageImage, displaySize: size))
        XCTAssertEqual(size.height, 369 * (792.0 / 612.0), accuracy: 0.01)
    }

    func testPortraitPageUsesFullWidthOnCompactPhone() {
        let size = PageModeLayoutSizing.displaySize(
            imageSize: portraitPageImage,
            containerSize: CGSize(width: 375, height: 520)
        )

        XCTAssertEqual(size.width, 351, accuracy: 0.001)
        XCTAssertLessThanOrEqual(size.height, 520)
        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: portraitPageImage, displaySize: size))
    }

    func testPortraitPageUsesFullWidthOnLargePhone() {
        let size = PageModeLayoutSizing.displaySize(
            imageSize: portraitPageImage,
            containerSize: CGSize(width: 430, height: 700)
        )

        XCTAssertEqual(size.width, 406, accuracy: 0.001)
        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: portraitPageImage, displaySize: size))
    }

    func testLandscapePageImagePreservesAspectRatioAtFullWidth() {
        let size = PageModeLayoutSizing.displaySize(
            imageSize: landscapePageImage,
            containerSize: CGSize(width: 393, height: 500)
        )

        XCTAssertEqual(size.width, 369, accuracy: 0.001)
        XCTAssertEqual(size.height, 369 * (612.0 / 792.0), accuracy: 0.01)
        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: landscapePageImage, displaySize: size))
    }

    func testWidthFillIsWiderThanAspectFitWhenHeightLimited() {
        let container = CGSize(width: 393, height: 400)
        let widthFill = PageModeLayoutSizing.displaySize(
            imageSize: portraitPageImage,
            containerSize: container
        )

        let widthScale = container.width / portraitPageImage.width
        let heightScale = container.height / portraitPageImage.height
        let fitScale = min(widthScale, heightScale)
        let aspectFit = CGSize(
            width: portraitPageImage.width * fitScale,
            height: portraitPageImage.height * fitScale
        )

        XCTAssertGreaterThan(widthFill.width, aspectFit.width)
        XCTAssertEqual(widthFill.width, 369, accuracy: 0.001)
    }

    func testDisplaySizeReturnsZeroForInvalidInput() {
        XCTAssertEqual(
            PageModeLayoutSizing.displaySize(imageSize: .zero, availableWidth: 300),
            .zero
        )
        XCTAssertEqual(
            PageModeLayoutSizing.displaySize(imageSize: portraitPageImage, availableWidth: 0),
            .zero
        )
    }
}

final class PageModeLayoutSizingSourceRegressionTests: XCTestCase {
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

    func testPageOverlayCanvasUsesWidthFillSizing() throws {
        let source = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertTrue(source.contains("PageModeLayoutSizing.displaySize"))
        XCTAssertFalse(source.contains("aspectFitSize"))
        XCTAssertTrue(source.contains("alignment: .top"))
        XCTAssertTrue(source.contains("ignoresSafeArea(edges: .horizontal)"))
    }

    func testPageEditorDoesNotAddCanvasPadding() throws {
        let source = try projectSource(named: "PageEditorView.swift", subdirectory: "Views")
        XCTAssertFalse(source.contains(".padding()\n            .id(pageItem.id)"))
    }
}
