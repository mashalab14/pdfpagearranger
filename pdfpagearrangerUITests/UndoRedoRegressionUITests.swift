import XCTest

final class UndoRedoRegressionUITests: PDFPagesUITestCase {
    func testUnifiedEditorUndoAndRedoButtonsExist() throws {
        try launchWithImportedPDF(pageCount: 2)

        let undoButton = app.buttons["undoButton"]
        let redoButton = app.buttons["redoButton"]
        XCTAssertTrue(undoButton.exists)
        XCTAssertTrue(redoButton.exists)
        XCTAssertFalse(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)
    }

    func testUnifiedEditorRotateUndoRedo() throws {
        try launchWithImportedPDF(pageCount: 2)

        let undoButton = app.buttons["undoButton"]
        let redoButton = app.buttons["redoButton"]

        app.buttons["pageToolbarRotate"].tap()
        XCTAssertTrue(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)

        undoButton.tap()
        XCTAssertFalse(undoButton.isEnabled)
        XCTAssertTrue(redoButton.isEnabled)

        redoButton.tap()
        XCTAssertTrue(undoButton.isEnabled)
        XCTAssertFalse(redoButton.isEnabled)
    }

    func testUndoAfterDeleteRestoresPageInOrganizer() throws {
        try launchWithImportedPDF(pageCount: 2)

        app.buttons["pageToolbarDelete"].tap()
        assertActivePage(pageNumber: 1, of: 1)

        openPagesOrganizer()
        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 2))
        dismissPagesOrganizer()

        app.buttons["undoButton"].tap()
        assertActivePage(pageNumber: 1, of: 2)

        openPagesOrganizer()
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 5))

        dismissPagesOrganizer()
        app.buttons["redoButton"].tap()
        assertActivePage(pageNumber: 1, of: 1)

        openPagesOrganizer()
        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_2"].waitForExistence(timeout: 2))
        dismissPagesOrganizer()
    }

    func testPageToolbarActionsShareDocumentHistory() throws {
        try launchWithImportedPDF(pageCount: 2)

        let undoButton = app.buttons["undoButton"]
        let redoButton = app.buttons["redoButton"]

        app.buttons["pageToolbarRotate"].tap()
        XCTAssertTrue(undoButton.isEnabled)

        undoButton.tap()
        XCTAssertTrue(redoButton.isEnabled)

        // Remain on the unified surface — there is no separate Page Mode push to leave.
        XCTAssertTrue(unifiedDocumentScroll.exists)
        XCTAssertTrue(app.buttons["pageModeAddButton"].exists)

        redoButton.tap()
        XCTAssertTrue(undoButton.isEnabled)
    }
}
