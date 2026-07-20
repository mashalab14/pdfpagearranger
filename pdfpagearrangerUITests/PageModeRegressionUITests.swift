import XCTest

final class PageModeRegressionUITests: PDFPagesUITestCase {
    func testUnifiedEditorOpensAfterImport() throws {
        try launchWithImportedPDF(pageCount: 2)

        XCTAssertTrue(pageModeView.exists)
        XCTAssertTrue(app.buttons["pageModeAddButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pageBottomToolbar"].exists)
        ensureFirstPageActive(of: 2)
    }

    func testPagesOrganizerDismissesBackToUnifiedEditor() throws {
        try launchWithImportedPDF(pageCount: 2)

        openPagesOrganizer()
        waitForThumbnail(pageNumber: 1)
        dismissPagesOrganizer()

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].exists)
        XCTAssertTrue(unifiedDocumentScroll.exists)
        XCTAssertTrue(app.buttons["pageModeAddButton"].exists)
    }

    func testPageModeAddSignatureOpensSignatureLibrary() throws {
        try launchWithImportedPDF(pageCount: 1, isolatedSignatureLibrary: true)

        app.buttons["pageModeAddButton"].tap()
        XCTAssertTrue(app.buttons["addQuickSignatureOption"].waitForExistence(timeout: 5))

        let libraryOption = app.buttons["addSignatureLibraryOption"]
        if !libraryOption.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(libraryOption.waitForExistence(timeout: 5))
        libraryOption.tap()

        XCTAssertTrue(app.descendants(matching: .any)["signatureLibraryView"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No saved signatures"].waitForExistence(timeout: 5))

        let createButton = app.buttons["Create Signature"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["signatureCaptureView"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["signatureClearButton"].exists)
        let saveAndUseButton = app.buttons["signatureSaveAndUseButton"]
        XCTAssertTrue(saveAndUseButton.exists)
        XCTAssertFalse(saveAndUseButton.isEnabled)
        XCTAssertTrue(app.buttons["signatureColor_black"].exists)
        XCTAssertTrue(app.buttons["signatureColor_red"].exists)
        XCTAssertTrue(app.buttons["signatureColor_purple"].exists)
    }
}
