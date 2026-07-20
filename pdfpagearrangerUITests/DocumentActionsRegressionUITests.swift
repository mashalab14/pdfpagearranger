import XCTest

final class DocumentActionsRegressionUITests: PDFPagesUITestCase {
    func testDocumentActionsButtonAppearsInUnifiedEditor() throws {
        try launchWithImportedPDF(pageCount: 2)

        XCTAssertTrue(documentActionsButton.exists)
        XCTAssertTrue(documentActionsButton.isEnabled)
    }

    func testDocumentActionsMenuOpensOnTap() throws {
        try launchWithImportedPDF(pageCount: 2)

        openDocumentActionsMenu()

        XCTAssertTrue(documentActionButton(named: "Compress").exists)
        XCTAssertTrue(documentActionButton(named: "Pages").exists)
        XCTAssertTrue(documentActionButton(named: "Export").exists)
    }

    func testCompressIsAccessibleFromDocumentActionsMenu() throws {
        try launchWithImportedPDF(pageCount: 2)

        tapDocumentAction("Compress")

        XCTAssertTrue(app.descendants(matching: .any)["compressionView"].waitForExistence(timeout: 5))
    }

    func testExportIsAccessibleFromDocumentActionsMenu() throws {
        try launchWithImportedPDF(pageCount: 2)

        tapDocumentAction("Export")
        assertExportShareSheetIsPresented()
    }

    func testCompressFlowStillWorksFromDocumentActionsMenu() throws {
        try launchWithImportedPDF(pageCount: 2)

        tapDocumentAction("Compress")

        let compressionView = app.descendants(matching: .any)["compressionView"]
        XCTAssertTrue(compressionView.waitForExistence(timeout: 5))

        app.buttons["Close"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 5))
        XCTAssertTrue(documentActionsButton.exists)
        XCTAssertTrue(unifiedDocumentScroll.exists)
    }

    func testExportFlowStillWorksFromDocumentActionsMenu() throws {
        try launchWithImportedPDF(pageCount: 2)

        tapDocumentAction("Export")
        assertExportShareSheetIsPresented()

        dismissExportShareSheetIfPresent()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 5))
        XCTAssertTrue(unifiedDocumentScroll.exists)
    }

    func testRotateEnablesUndo() throws {
        try launchWithImportedPDF(pageCount: 2)

        let undoButton = app.buttons["undoButton"]
        XCTAssertFalse(undoButton.isEnabled)

        app.buttons["pageToolbarRotate"].tap()
        XCTAssertTrue(undoButton.waitForExistence(timeout: 3))
        XCTAssertTrue(undoButton.isEnabled)
    }

    func testDuplicateIncreasesPageCount() throws {
        try launchWithImportedPDF(pageCount: 2)
        ensureFirstPageActive(of: 2)

        app.buttons["pageToolbarDuplicate"].tap()
        assertActivePage(pageNumber: 2, of: 3)

        openPagesOrganizer()
        waitForThumbnail(pageNumber: 3)
        dismissPagesOrganizer()
    }

    func testDeleteReducesPageCount() throws {
        try launchWithImportedPDF(pageCount: 3)
        ensureFirstPageActive(of: 3)

        activatePageViaOrganizer(2)
        assertActivePage(pageNumber: 2, of: 3)

        app.buttons["pageToolbarDelete"].tap()
        assertActivePage(pageNumber: 2, of: 2)

        openPagesOrganizer()
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_2"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["pageThumbnail_3"].exists)
        dismissPagesOrganizer()
    }

    func testUndoAfterDeleteRestoresPage() throws {
        try launchWithImportedPDF(pageCount: 2)
        ensureFirstPageActive(of: 2)

        app.buttons["pageToolbarDelete"].tap()
        assertActivePage(pageNumber: 1, of: 1)

        app.buttons["undoButton"].tap()
        assertActivePage(pageNumber: 1, of: 2)

        openPagesOrganizer()
        waitForThumbnail(pageNumber: 2)
        dismissPagesOrganizer()
    }
}
