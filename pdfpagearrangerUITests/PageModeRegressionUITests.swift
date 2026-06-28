import XCTest

final class PageModeRegressionUITests: PDFPagesUITestCase {
    func testPageModeOpensFromThumbnailTap() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.descendants(matching: .any)["pageThumbnail_1"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["pageModeAddButton"].exists)
    }

    func testReturnToDocumentModeFromPageMode() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        app.otherElements["pageThumbnail_1"].tap()
        XCTAssertTrue(app.otherElements["pageModeView"].waitForExistence(timeout: 10))

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 10))
    }

    func testPageModeAddSignatureOpensSignatureLibrary() throws {
        try launchWithImportedPDF(pageCount: 1, isolatedSignatureLibrary: true)
        waitForThumbnail(pageNumber: 1)

        app.descendants(matching: .any)["pageThumbnail_1"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].waitForExistence(timeout: 10))

        app.buttons["pageModeAddButton"].tap()
        app.buttons["addSignatureOption"].tap()

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
