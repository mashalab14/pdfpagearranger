import XCTest
@testable import pdfpagearranger

final class ContextualControlMetricsRegressionTests: XCTestCase {
    func testMinimumTapTargetIsFiftyTwoPoints() {
        XCTAssertEqual(ContextualControlMetrics.minimumTapTarget, 52)
    }

    func testPresetColorDiameterStaysCompact() {
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.presetColorDiameter, 24)
        XCTAssertLessThanOrEqual(ContextualControlMetrics.presetColorDiameter, 28)
    }

    func testToolbarWidthFitsThreeEqualCells() {
        let expected = ContextualControlMetrics.horizontalPadding * 2
            + ContextualControlMetrics.minimumTapTarget * 3
            + ContextualControlMetrics.toolbarCellSpacing * 2
            + 2
        XCTAssertEqual(ContextualControlMetrics.signatureToolbarWidth, expected)
        XCTAssertEqual(SignatureOverlayMenuEngine.menuWidth, expected)
    }

    func testPopoverSizeMatchesMetrics() {
        XCTAssertEqual(
            SignatureEditPopoverEngine.popoverSize.width,
            ContextualControlMetrics.popoverWidth
        )
        XCTAssertEqual(
            SignatureEditPopoverEngine.popoverSize.height,
            ContextualControlMetrics.popoverHeight
        )
    }

    func testThicknessRowUsesTenColumnGrid() {
        XCTAssertEqual(
            ContextualControlMetrics.thicknessRowPaletteColumns
                + ContextualControlMetrics.thicknessRowMinusColumns
                + ContextualControlMetrics.thicknessRowLabelColumns
                + ContextualControlMetrics.thicknessRowPlusColumns,
            ContextualControlMetrics.thicknessRowColumnCount
        )
        XCTAssertEqual(
            ContextualControlMetrics.thicknessRowColumnUnit * ContextualControlMetrics.thicknessRowColumnCount,
            ContextualControlMetrics.popoverContentWidth,
            accuracy: 0.001
        )
    }

    func testSharedGlassUsesSoftFloatingShadow() {
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.glassShadowOpacity, 0.10)
        XCTAssertLessThanOrEqual(ContextualControlMetrics.glassShadowOpacity, 0.18)
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.glassShadowRadius, 8)
        XCTAssertLessThanOrEqual(ContextualControlMetrics.glassShadowRadius, 12)
    }

    func testGlassCornerRadiusIsLargeAndContinuous() {
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.glassCornerRadius, 18)
    }
}

/// Preserves suite name used by existing regression filters.
typealias SignatureContextualUIMetricsRegressionTests = ContextualControlMetricsRegressionTests
