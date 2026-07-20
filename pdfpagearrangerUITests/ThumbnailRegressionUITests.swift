import XCTest

final class ThumbnailRegressionUITests: PDFPagesUITestCase {
    func testThumbnailsAppearWithPageNumbersInPagesOrganizer() throws {
        try launchWithImportedPDF(pageCount: 3)
        openPagesOrganizer()

        for page in 1...3 {
            waitForThumbnail(pageNumber: page)
            XCTAssertTrue(
                app.staticTexts["pageNumberLabel_\(page)"].exists,
                "Page number label \(page) should be visible in the Pages organizer"
            )
        }
        dismissPagesOrganizer()
    }

    func testThumbnailsRenderWithoutPlaceholderStuckState() throws {
        try launchWithImportedPDF(pageCount: 2)
        openPagesOrganizer()

        waitForThumbnail(pageNumber: 1)
        waitForThumbnail(pageNumber: 2)

        let firstThumbnail = waitForThumbnail(pageNumber: 1)
        XCTAssertTrue(firstThumbnail.exists)
        XCTAssertGreaterThan(firstThumbnail.frame.width, 40)
        XCTAssertGreaterThan(firstThumbnail.frame.height, 40)
        dismissPagesOrganizer()
    }
}
