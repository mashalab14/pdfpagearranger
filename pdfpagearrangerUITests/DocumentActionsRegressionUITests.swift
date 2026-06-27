import XCTest

final class DocumentActionsRegressionUITests: PDFPagesUITestCase {
    func testRotateEnablesUndo() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        let undoButton = app.buttons["undoButton"]
        XCTAssertFalse(undoButton.isEnabled)

        app.buttons["rotatePage_1"].tap()
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3))
        XCTAssertTrue(undoButton.isEnabled)
    }

    func testDuplicateIncreasesThumbnailCount() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.buttons["duplicatePage_1"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_3"].waitForExistence(timeout: 5))
    }

    func testDeleteReducesThumbnailCount() throws {
        try launchWithImportedPDF(pageCount: 3)
        waitForThumbnail(pageNumber: 1)

        app.buttons["deletePage_2"].tap()

        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_3"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_1"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_2"].exists)
    }

    func testUndoAfterDeleteRestoresThumbnail() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.buttons["deletePage_1"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 2))

        app.buttons["undoButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 5))
    }
}
