import XCTest

final class OverlayPersistenceUITests: PDFPagesUITestCase {
    func testSeededOverlayPersistsAfterReturningFromPageMode() throws {
        try launchWithImportedPDF(pageCount: 1, seedOverlay: true)
        waitForThumbnail(pageNumber: 1)

        app.descendants(matching: .any)["pageThumbnail_1"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].waitForExistence(timeout: 10))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 10))

        waitForThumbnail(pageNumber: 1)
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_1"].exists)
    }
}
