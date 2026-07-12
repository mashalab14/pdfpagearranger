import XCTest

final class ImportRegressionUITests: PDFPagesUITestCase {
    func testEmptyStateShowsImportButton() throws {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["openPDFButton"].exists)
        XCTAssertTrue(app.buttons["scanDocumentButton"].exists)
        XCTAssertTrue(app.buttons["importPhotosButton"].exists)
    }

    func testImportOpensDocumentModeWithCorrectPageCount() throws {
        try launchWithImportedPDF(pageCount: 4)

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].exists)
        for page in 1...4 {
            XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_\(page)"].waitForExistence(timeout: 10))
        }
    }
}
