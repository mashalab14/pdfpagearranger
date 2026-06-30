import XCTest
@testable import pdfpagearranger

final class SignatureContextualUIMetricsRegressionTests: XCTestCase {
    func testMinimumTapTargetIsFiftyTwoPoints() {
        XCTAssertEqual(SignatureContextualUIMetrics.minimumTapTarget, 52)
    }

    func testPresetColorDiameterStaysCompact() {
        XCTAssertGreaterThanOrEqual(SignatureContextualUIMetrics.presetColorDiameter, 24)
        XCTAssertLessThanOrEqual(SignatureContextualUIMetrics.presetColorDiameter, 28)
    }

    func testToolbarWidthFitsThreeEqualCells() {
        let expected = SignatureContextualUIMetrics.minimumTapTarget * 3
            + SignatureContextualUIMetrics.toolbarCellSpacing * 2
            + 2
            + SignatureContextualUIMetrics.toolbarHorizontalPadding * 2
        XCTAssertEqual(SignatureContextualUIMetrics.signatureToolbarWidth, expected)
        XCTAssertEqual(SignatureOverlayMenuEngine.menuWidth, expected)
    }

    func testPopoverSizeMatchesMetrics() {
        XCTAssertEqual(
            SignatureEditPopoverEngine.popoverSize.width,
            SignatureContextualUIMetrics.popoverWidth
        )
        XCTAssertEqual(
            SignatureEditPopoverEngine.popoverSize.height,
            SignatureContextualUIMetrics.popoverHeight
        )
    }
}
