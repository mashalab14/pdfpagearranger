import XCTest
@testable import pdfpagearranger

final class ScanDraftPreviewLoadGuardRegressionTests: XCTestCase {
    func testStalePreviewResultIsIgnoredWhenSelectionChanged() {
        let page1 = UUID()
        let page2 = UUID()

        XCTAssertFalse(
            ScanDraftPreviewLoadGuard.shouldApplyLoadedImage(
                requestedPageID: page1,
                currentPageID: page2,
                isCancelled: false
            )
        )
    }

    func testMatchingSelectionAllowsPreviewUpdate() {
        let page1 = UUID()

        XCTAssertTrue(
            ScanDraftPreviewLoadGuard.shouldApplyLoadedImage(
                requestedPageID: page1,
                currentPageID: page1,
                isCancelled: false
            )
        )
    }

    func testCancelledPreviewResultIsIgnored() {
        let page1 = UUID()

        XCTAssertFalse(
            ScanDraftPreviewLoadGuard.shouldApplyLoadedImage(
                requestedPageID: page1,
                currentPageID: page1,
                isCancelled: true
            )
        )
    }
}
