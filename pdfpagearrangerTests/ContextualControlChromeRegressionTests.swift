import XCTest
@testable import pdfpagearranger

final class ContextualGlassContainerRegressionTests: XCTestCase {
    func testSharedGlassContainerUsedBySignatureToolbar() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualGlassContainer()"))
        XCTAssertTrue(menu.contains("contextualExpandedTapTarget"))
        XCTAssertTrue(container.contains("case .capsule:"))
        XCTAssertFalse(menu.contains("glassEffect("))
    }

    func testSignatureEditPopoverUsesSameFloatingPanelContainer() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("contextualGlassContainer("))
        XCTAssertTrue(popover.contains("roundedRectangle(cornerRadius: ContextualControlMetrics.popoverCornerRadius)"))
        XCTAssertTrue(popover.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(popover.contains(".background(.regularMaterial"))
        XCTAssertFalse(popover.contains("glassEffect("))
    }

    func testFloatingPanelsUseWhiteTranslucentBackgroundWithoutGlass() throws {
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(container.contains("fixedSize(horizontal: true, vertical: true)"))
        XCTAssertTrue(container.contains("Color.white.opacity(ContextualControlMetrics.floatingPanelBackgroundOpacity)"))
        XCTAssertTrue(container.contains("toolbarCapsuleCornerRadius"))
        XCTAssertTrue(metrics.contains("floatingPanelBackgroundOpacity: CGFloat = 0.8"))
        XCTAssertFalse(container.contains("ultraThinMaterial"))
        XCTAssertFalse(container.contains("glassEffect("))
        XCTAssertFalse(container.contains("ZStack"))
        XCTAssertFalse(container.contains("GlassEffectContainer"))
    }

    func testCanvasDoesNotWrapContextualControlsInGlassEffectContainer() throws {
        let canvas = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertFalse(canvas.contains("GlassEffectContainer"))
        XCTAssertFalse(canvas.contains("glassEffectID"))
    }

    func testForegroundContentIsNotInsideGlassEffectHierarchy() throws {
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        XCTAssertFalse(container.contains("glassEffect("))
        XCTAssertTrue(container.contains("content\n            .padding(.horizontal, horizontalPadding)"))
        XCTAssertTrue(container.contains(".background {"))
    }

    func testPositionedContextualControlsUseFixedSizeBeforePosition() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains(".fixedSize(horizontal: true, vertical: true)\n        .position(anchorPoint)"))
        XCTAssertTrue(popover.contains(".fixedSize(horizontal: true, vertical: true)\n        .position(anchorPoint)"))
    }

    func testToolbarUsesCompactVisibleHeightAndBoldIcons() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(menu.contains("toolbarVisibleHeight"))
        XCTAssertTrue(menu.contains("toolbarSymbolFont"))
        XCTAssertTrue(metrics.contains("weight: .bold"))
        XCTAssertTrue(metrics.contains("toolbarCapsuleCornerRadius"))
        XCTAssertTrue(metrics.contains("floatingPanelShadowOpacity"))
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
}

/// Preserves suite name used by existing regression filters.
typealias ContextualControlChromeRegressionTests = ContextualGlassContainerRegressionTests
