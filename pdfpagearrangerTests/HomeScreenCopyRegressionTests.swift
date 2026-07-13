import XCTest
@testable import pdfpagearranger

final class HomeScreenCopyRegressionTests: XCTestCase {
    func testHomeScreenCopyUsesOutcomeFocusedLabels() {
        XCTAssertEqual(HomeScreenCopy.openPDF, "Open PDF")
        XCTAssertEqual(HomeScreenCopy.scanToPDF, "Scan to PDF")
        XCTAssertEqual(HomeScreenCopy.photoToPDF, "Photo to PDF")
        XCTAssertEqual(
            HomeScreenCopy.subtitle,
            "Edit PDFs, scan documents, and convert photos into PDFs."
        )
    }

    func testHomeScreenCopyProvidesAccessibilityHints() {
        XCTAssertFalse(HomeScreenCopy.openPDFAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.scanToPDFAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.photoToPDFAccessibilityHint.isEmpty)
    }
}
