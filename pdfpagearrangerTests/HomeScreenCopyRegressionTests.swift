import XCTest
@testable import pdfpagearranger

final class HomeScreenCopyRegressionTests: XCTestCase {
    func testHomeScreenCopyUsesOutcomeFocusedLabels() {
        XCTAssertEqual(HomeScreenCopy.openDocument, "Open Document")
        XCTAssertEqual(HomeScreenCopy.createDocument, "Create Document")
        XCTAssertEqual(HomeScreenCopy.scanToPDF, "Scan to PDF")
        XCTAssertEqual(HomeScreenCopy.photoToPDF, "Photo to PDF")
        XCTAssertEqual(HomeScreenCopy.recentDocuments, "Recent Documents")
        XCTAssertEqual(
            HomeScreenCopy.subtitle,
            "Open, create, scan, or convert photos into PDFs."
        )
    }

    func testHomeScreenCopyProvidesAccessibilityHints() {
        XCTAssertFalse(HomeScreenCopy.openDocumentAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.createDocumentAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.scanToPDFAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.photoToPDFAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.recentDocumentsMoreAccessibilityHint.isEmpty)
    }
}
