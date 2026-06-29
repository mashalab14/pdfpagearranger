import XCTest

final class PageModeNavigationUITests: PDFPagesUITestCase {
    private var pageModeView: XCUIElement {
        app.descendants(matching: .any)["pageModeView"]
    }

    private func openPageMode(onPage pageNumber: Int = 1) {
        waitForThumbnail(pageNumber: pageNumber)
        app.descendants(matching: .any)["pageThumbnail_\(pageNumber)"].tap()
        XCTAssertTrue(pageModeView.waitForExistence(timeout: 10))
    }

    private func assertPageModeShows(pageNumber: Int, of total: Int) {
        XCTAssertEqual(
            pageModeView.value as? String,
            "page \(pageNumber) of \(total)"
        )
    }

    func testSwipeLeftMovesToNextPage() throws {
        try launchWithImportedPDF(pageCount: 3)
        openPageMode(onPage: 1)

        pageModeView.swipeLeft()
        assertPageModeShows(pageNumber: 2, of: 3)
    }

    func testSwipeRightMovesToPreviousPage() throws {
        try launchWithImportedPDF(pageCount: 3)
        openPageMode(onPage: 2)

        pageModeView.swipeRight()
        assertPageModeShows(pageNumber: 1, of: 3)
    }

    func testFirstPageCannotNavigateBackward() throws {
        try launchWithImportedPDF(pageCount: 3)
        openPageMode(onPage: 1)

        pageModeView.swipeRight()
        assertPageModeShows(pageNumber: 1, of: 3)
    }

    func testLastPageCannotNavigateForward() throws {
        try launchWithImportedPDF(pageCount: 3)
        openPageMode(onPage: 3)

        pageModeView.swipeLeft()
        assertPageModeShows(pageNumber: 3, of: 3)
    }

    func testDraggingOverlayDoesNotTriggerPageNavigation() throws {
        try launchWithImportedPDF(pageCount: 3, seedOverlay: true)
        openPageMode(onPage: 1)

        pageModeView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()

        let resizeHandle = app.otherElements["overlayResizeHandle"]
        XCTAssertTrue(resizeHandle.waitForExistence(timeout: 5))

        let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 2.0, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: end)

        assertPageModeShows(pageNumber: 1, of: 3)
    }

    func testResizingOverlayDoesNotTriggerPageNavigation() throws {
        try launchWithImportedPDF(pageCount: 3, seedOverlay: true)
        openPageMode(onPage: 1)

        pageModeView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()

        let resizeHandle = app.otherElements["overlayResizeHandle"]
        XCTAssertTrue(resizeHandle.waitForExistence(timeout: 5))

        let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 2.0, dy: 1.5))
        start.press(forDuration: 0.2, thenDragTo: end)

        assertPageModeShows(pageNumber: 1, of: 3)
    }

    func testOverlayStateRemainsAfterNavigatingAwayAndBack() throws {
        try launchWithImportedPDF(pageCount: 2, seedOverlay: true)
        openPageMode(onPage: 1)

        pageModeView.swipeLeft()
        assertPageModeShows(pageNumber: 2, of: 2)

        pageModeView.swipeRight()
        assertPageModeShows(pageNumber: 1, of: 2)
    }
}
