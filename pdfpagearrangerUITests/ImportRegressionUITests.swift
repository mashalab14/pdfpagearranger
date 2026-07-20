import XCTest

final class ImportRegressionUITests: PDFPagesUITestCase {
    func testEmptyStateShowsImportButton() throws {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["openPDFButton"].exists)
        XCTAssertTrue(app.buttons["createDocumentButton"].exists)
        XCTAssertTrue(app.buttons["scanDocumentButton"].exists)
        XCTAssertTrue(app.buttons["importPhotosButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["homePrimaryActions"].exists)
    }

    func testImportOpensUnifiedEditorWithCorrectPageCount() throws {
        try launchWithImportedPDF(pageCount: 4)

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].exists)
        XCTAssertTrue(unifiedDocumentScroll.exists)
        ensureFirstPageActive(of: 4)
        XCTAssertTrue(
            documentPageSlot(1).waitForExistence(timeout: 10),
            "First page slot should exist in the unified document"
        )

        // Full page count is verified via the Pages organizer; LazyVStack may not materialize distant slots.
        openPagesOrganizer()
        for page in 1...4 {
            waitForThumbnail(pageNumber: page)
        }
        dismissPagesOrganizer()
    }
}
