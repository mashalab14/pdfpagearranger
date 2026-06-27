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

    func testPageModeAddSignatureOpensCaptureCanvas() throws {
        try launchWithImportedPDF(pageCount: 1)
        waitForThumbnail(pageNumber: 1)

        app.descendants(matching: .any)["pageThumbnail_1"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].waitForExistence(timeout: 10))

        app.buttons["pageModeAddButton"].tap()
        app.buttons["addSignatureOption"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["signatureCaptureView"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["signatureClearButton"].exists)
        let useSignatureButton = app.buttons["signatureUseButton"]
        XCTAssertTrue(useSignatureButton.exists)
        XCTAssertFalse(useSignatureButton.isEnabled)
        XCTAssertTrue(app.buttons["signatureColor_black"].exists)
    }
}
