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

    func testPopoverUsesLargeRoundedRectangleCornerRadius() {
        XCTAssertEqual(ContextualControlMetrics.popoverCornerRadius, 16)
        XCTAssertEqual(ContextualControlMetrics.glassCornerRadius, ContextualControlMetrics.popoverCornerRadius)
        XCTAssertEqual(ContextualControlMetrics.cornerRadius, ContextualControlMetrics.popoverCornerRadius)
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

    func testFloatingPanelUsesDualLayerElevationShadow() {
        XCTAssertEqual(ContextualControlMetrics.floatingPanelKeyShadowOpacity, 0.10)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelKeyShadowRadius, 10)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelKeyShadowXOffset, 0)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelKeyShadowYOffset, 2)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelAmbientShadowOpacity, 0.08)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelAmbientShadowRadius, 30)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelAmbientShadowXOffset, 0)
        XCTAssertEqual(ContextualControlMetrics.floatingPanelAmbientShadowYOffset, 12)
    }

    func testFloatingPanelShadowMetricsAreDefinedInMetricsSource() throws {
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(metrics.contains("floatingPanelKeyShadowOpacity"))
        XCTAssertTrue(metrics.contains("floatingPanelKeyShadowRadius"))
        XCTAssertTrue(metrics.contains("floatingPanelKeyShadowXOffset"))
        XCTAssertTrue(metrics.contains("floatingPanelKeyShadowYOffset"))
        XCTAssertTrue(metrics.contains("floatingPanelAmbientShadowOpacity"))
        XCTAssertTrue(metrics.contains("floatingPanelAmbientShadowRadius"))
        XCTAssertTrue(metrics.contains("floatingPanelAmbientShadowXOffset"))
        XCTAssertTrue(metrics.contains("floatingPanelAmbientShadowYOffset"))
        XCTAssertFalse(metrics.contains("floatingPanelShadowOpacity"))
    }

    func testToolbarHasIncreasedBreathingRoomPadding() {
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.toolbarHorizontalPadding, 14)
        XCTAssertGreaterThanOrEqual(ContextualControlMetrics.toolbarVerticalPadding, 6)
    }

    func testToolbarSitsHigherAboveSignature() {
        XCTAssertEqual(SignatureOverlayMenuEngine.verticalOffset, 40)
    }

    func testToolbarCapsuleCornerRadiusIsHalfShellHeight() {
        XCTAssertEqual(
            ContextualControlMetrics.toolbarCapsuleCornerRadius,
            ContextualControlMetrics.toolbarShellHeight / 2
        )
    }

    func testFloatingPanelUsesWhiteTranslucentBackground() throws {
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(metrics.contains("floatingPanelBackgroundOpacity: CGFloat = 0.8"))
    }

    private func projectSource(named fileName: String, subdirectory: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot
                .appendingPathComponent("pdfpagearranger")
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(fileName),
            encoding: .utf8
        )
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
