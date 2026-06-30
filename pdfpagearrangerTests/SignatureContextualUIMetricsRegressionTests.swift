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

    func testToolbarWidthFitsThreeCompactCells() {
        let expected = ContextualControlMetrics.toolbarHorizontalPadding * 2
            + ContextualControlMetrics.toolbarVisibleCellWidth * 3
            + 2
        XCTAssertEqual(ContextualControlMetrics.signatureToolbarWidth, expected)
        XCTAssertEqual(SignatureOverlayMenuEngine.menuWidth, expected)
    }

    func testToolbarCapsuleRadiusMatchesHalfHeight() {
        XCTAssertEqual(
            ContextualControlMetrics.toolbarCapsuleRadius,
            ContextualControlMetrics.toolbarCapsuleHeight / 2
        )
        XCTAssertEqual(ContextualControlMetrics.toolbarCapsuleHeight, 40)
    }

    func testPopoverUsesDistinctRoundedRectangleRadius() {
        XCTAssertEqual(ContextualControlMetrics.popoverCornerRadius, 14)
        XCTAssertLessThan(
            ContextualControlMetrics.popoverCornerRadius,
            ContextualControlMetrics.toolbarCapsuleRadius
        )
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

    func testSharedGlassUsesElevatedFloatingShadow() {
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.toolbarShadowOpacity, 0.14)
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.toolbarShadowRadius, 10)
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.popoverShadowOpacity, 0.12)
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.popoverShadowRadius, 8)
    }

    func testToolbarTapOutsetsPreserveCompactLayout() {
        XCTAssertEqual(
            ContextualControlMetrics.toolbarVisibleCellWidth
                + ContextualControlMetrics.toolbarTapOutsetHorizontal * 2,
            ContextualControlMetrics.minimumTapTarget
        )
        XCTAssertEqual(
            ContextualControlMetrics.toolbarVisibleHeight
                + ContextualControlMetrics.toolbarTapOutsetVertical * 2,
            ContextualControlMetrics.minimumTapTarget
        )
    }
}

/// Preserves suite name used by existing regression filters.
typealias SignatureContextualUIMetricsRegressionTests = ContextualControlMetricsRegressionTests
