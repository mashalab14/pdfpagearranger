import XCTest

final class OverlayPersistenceUITests: PDFPagesUITestCase {
    func testSeededOverlayRemainsOnUnifiedEditorSurface() throws {
        try launchWithImportedPDF(pageCount: 1, seedOverlay: true)

        XCTAssertTrue(pageModeView.exists)
        XCTAssertTrue(documentPageSlot(1).waitForExistence(timeout: 10))
        selectSeededImageOverlay()

        // Clear overlay selection so chrome (⋯ menu) remains tappable.
        documentPageSlot(1).coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()

        openPagesOrganizer()
        waitForThumbnail(pageNumber: 1)
        dismissPagesOrganizer()

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].exists)
        XCTAssertTrue(unifiedDocumentScroll.exists)
        XCTAssertTrue(documentPageSlot(1).exists)
        selectSeededImageOverlay()
    }
}
