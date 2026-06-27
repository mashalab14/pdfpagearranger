import XCTest

final class ThumbnailRegressionUITests: PDFPagesUITestCase {
    func testThumbnailsAppearWithPageNumbers() throws {
        try launchWithImportedPDF(pageCount: 3)

        for page in 1...3 {
            waitForThumbnail(pageNumber: page)
            XCTAssertTrue(app.staticTexts["pageNumberLabel_\(page)"].exists, "Page number label \(page) should be visible")
        }
    }

    func testThumbnailsRenderWithoutPlaceholderStuckState() throws {
        try launchWithImportedPDF(pageCount: 2)

        waitForThumbnail(pageNumber: 1)
        waitForThumbnail(pageNumber: 2)

        let firstThumbnail = waitForThumbnail(pageNumber: 1)
        XCTAssertTrue(firstThumbnail.exists)
        XCTAssertGreaterThan(firstThumbnail.frame.width, 40)
        XCTAssertGreaterThan(firstThumbnail.frame.height, 40)
    }
}
