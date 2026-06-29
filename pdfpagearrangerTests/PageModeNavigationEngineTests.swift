import XCTest
@testable import pdfpagearranger

final class PageModeNavigationEngineTests: XCTestCase {
    func testAdjacentPageIndexReturnsNextPage() {
        XCTAssertEqual(
            PageModeNavigationEngine.adjacentPageIndex(
                currentIndex: 1,
                pageCount: 4,
                direction: .next
            ),
            2
        )
    }

    func testAdjacentPageIndexReturnsPreviousPage() {
        XCTAssertEqual(
            PageModeNavigationEngine.adjacentPageIndex(
                currentIndex: 2,
                pageCount: 4,
                direction: .previous
            ),
            1
        )
    }

    func testFirstPageCannotNavigateBackward() {
        XCTAssertNil(
            PageModeNavigationEngine.adjacentPageIndex(
                currentIndex: 0,
                pageCount: 4,
                direction: .previous
            )
        )
    }

    func testLastPageCannotNavigateForward() {
        XCTAssertNil(
            PageModeNavigationEngine.adjacentPageIndex(
                currentIndex: 3,
                pageCount: 4,
                direction: .next
            )
        )
    }

    func testShouldAllowPageSwipeWhenIdleAndNotZoomed() {
        XCTAssertTrue(
            PageModeNavigationEngine.shouldAllowPageSwipe(
                overlayManipulationActive: false,
                isPageZoomed: false
            )
        )
    }

    func testShouldBlockPageSwipeDuringOverlayManipulation() {
        XCTAssertFalse(
            PageModeNavigationEngine.shouldAllowPageSwipe(
                overlayManipulationActive: true,
                isPageZoomed: false
            )
        )
    }

    func testShouldBlockPageSwipeWhilePageIsZoomed() {
        XCTAssertFalse(
            PageModeNavigationEngine.shouldAllowPageSwipe(
                overlayManipulationActive: false,
                isPageZoomed: true
            )
        )
    }

    func testDirectionRecognizesSwipeLeftAsNext() {
        XCTAssertEqual(
            PageModeNavigationEngine.direction(for: CGSize(width: -120, height: 10)),
            .next
        )
    }

    func testDirectionRecognizesSwipeRightAsPrevious() {
        XCTAssertEqual(
            PageModeNavigationEngine.direction(for: CGSize(width: 120, height: 10)),
            .previous
        )
    }

    func testDirectionIgnoresShortOrVerticalDrags() {
        XCTAssertNil(PageModeNavigationEngine.direction(for: CGSize(width: -20, height: 0)))
        XCTAssertNil(PageModeNavigationEngine.direction(for: CGSize(width: -120, height: 120)))
    }
}
