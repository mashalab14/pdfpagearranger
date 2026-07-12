import XCTest

final class UndoRedoRegressionUITests: PDFPagesUITestCase {
    func testDocumentModeUndoAndRedoButtonsExist() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        let undoButton = app.buttons["undoButton"]
        let redoButton = app.buttons["redoButton"]
        XCTAssertTrue(undoButton.exists)
        XCTAssertTrue(redoButton.exists)
        XCTAssertFalse(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)
    }

    func testDocumentModeRotateUndoRedo() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        let undoButton = app.buttons["undoButton"]
        let redoButton = app.buttons["redoButton"]

        app.buttons["rotatePage_1"].tap()
        XCTAssertTrue(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)

        undoButton.tap()
        XCTAssertFalse(undoButton.isEnabled)
        XCTAssertTrue(redoButton.isEnabled)

        redoButton.tap()
        XCTAssertTrue(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)
    }

    func testDocumentModeUndoAfterDeleteRestoresThumbnail() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.buttons["deletePage_1"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 2))

        app.buttons["undoButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 5))

        app.buttons["redoButton"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 2))
    }

    func testPageModeUndoAndRedoButtonsExist() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        openPageMode(pageNumber: 1)

        let undoButton = app.buttons["pageModeUndoButton"]
        let redoButton = app.buttons["pageModeRedoButton"]
        XCTAssertTrue(undoButton.exists)
        XCTAssertTrue(redoButton.exists)
        XCTAssertFalse(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)
    }

    func testPageModeUndoRedoUsesSharedHistoryWithDocumentMode() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.buttons["rotatePage_1"].tap()
        openPageMode(pageNumber: 1)

        let undoButton = app.buttons["pageModeUndoButton"]
        let redoButton = app.buttons["pageModeRedoButton"]
        XCTAssertTrue(undoButton.isEnabled)

        undoButton.tap()
        XCTAssertTrue(redoButton.isEnabled)

        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["redoButton"].isEnabled)

        openPageMode(pageNumber: 1)
        redoButton.tap()
        XCTAssertTrue(undoButton.isEnabled)
    }

    func testDocumentModeRedoAfterPageModeUndo() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.buttons["rotatePage_1"].tap()
        openPageMode(pageNumber: 1)
        app.buttons["pageModeUndoButton"].tap()

        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 10))

        XCTAssertTrue(app.buttons["redoButton"].isEnabled)
        app.buttons["redoButton"].tap()
        XCTAssertTrue(app.buttons["undoButton"].isEnabled)
    }

    private func openPageMode(pageNumber: Int) {
        app.descendants(matching: .any)["pageThumbnail_\(pageNumber)"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].waitForExistence(timeout: 10))
    }
}
