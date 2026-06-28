import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class OverlayInteractionEngineTests: XCTestCase {
    func testDragUsesStartCenterPlusTranslationWithoutJump() {
        let start = CGPoint(x: 200, y: 300)
        let first = OverlayInteractionEngine.dragDisplayCenter(
            startCenter: start,
            translation: CGSize(width: 0, height: 0),
            canvasScale: 1
        )
        XCTAssertEqual(first.x, start.x, accuracy: 0.001)
        XCTAssertEqual(first.y, start.y, accuracy: 0.001)

        let moved = OverlayInteractionEngine.dragDisplayCenter(
            startCenter: start,
            translation: CGSize(width: 24, height: -12),
            canvasScale: 2
        )
        XCTAssertEqual(moved.x, 212, accuracy: 0.001)
        XCTAssertEqual(moved.y, 294, accuracy: 0.001)
    }

    func testResizeHandlePreservesAspectRatio() {
        let startSize = CGSize(width: 120, height: 60)
        let resized = OverlayInteractionEngine.uniformResizedLayoutSize(
            startSize: startSize,
            translation: CGSize(width: 40, height: 10),
            canvasScale: 1,
            minSize: CGSize(width: 20, height: 10),
            maxSize: CGSize(width: 400, height: 400)
        )

        XCTAssertGreaterThan(resized.width, startSize.width)
        XCTAssertGreaterThan(resized.height, startSize.height)
        XCTAssertEqual(resized.width / resized.height, 2, accuracy: 0.01)
    }

    func testResizeHandleRespectsMinimumSize() {
        let startSize = CGSize(width: 40, height: 20)
        let resized = OverlayInteractionEngine.uniformResizedLayoutSize(
            startSize: startSize,
            translation: CGSize(width: -200, height: -200),
            canvasScale: 1,
            minSize: CGSize(width: 30, height: 15),
            maxSize: CGSize(width: 400, height: 400)
        )

        XCTAssertGreaterThanOrEqual(resized.width, 30)
        XCTAssertGreaterThanOrEqual(resized.height, 15)
    }

    func testPinchResizePreservesAspectRatio() {
        let start = CGSize(width: 0.3, height: 0.15)
        let resized = OverlayInteractionEngine.magnificationResizedNormalizedSize(
            startNormalizedSize: start,
            magnification: 1.6
        )

        XCTAssertEqual(resized.width / resized.height, 2, accuracy: 0.01)
        XCTAssertLessThanOrEqual(resized.width, OverlayInteractionEngine.maxNormalizedSize)
        XCTAssertGreaterThanOrEqual(resized.width, OverlayInteractionEngine.minNormalizedSize)
    }
}
