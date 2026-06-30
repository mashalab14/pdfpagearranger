import XCTest
@testable import pdfpagearranger

final class ContextualGlassContainerRegressionTests: XCTestCase {
    func testSharedGlassContainerUsedBySignatureToolbar() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualGlassContainer()"))
        XCTAssertTrue(menu.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(menu.contains("Color.white.opacity"))
        XCTAssertFalse(menu.contains(".capsule"))
    }

    func testSignatureEditPopoverUsesSameFloatingPanelContainer() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("contextualGlassContainer("))
        XCTAssertTrue(popover.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(popover.contains(".background(.regularMaterial"))
        XCTAssertFalse(popover.contains(".capsule"))
    }

    func testUnifiedFloatingPanelUsesClearGlassAndRoundedRectangle() throws {
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(container.contains("ZStack"))
        XCTAssertTrue(container.contains("floatingPanelBackground"))
        XCTAssertTrue(container.contains("glassEffect("))
        XCTAssertTrue(container.contains(".rect(cornerRadius: cornerRadius, style: .continuous)"))
        XCTAssertTrue(metrics.contains("floatingPanelGlass: Glass = .clear"))
        XCTAssertFalse(container.contains("Capsule()"))
        XCTAssertFalse(container.contains("glassEffect(.regular"))
        XCTAssertFalse(container.contains(".background {"))
    }

    func testCanvasDoesNotWrapContextualControlsInGlassEffectContainer() throws {
        let canvas = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertFalse(canvas.contains("GlassEffectContainer"))
        XCTAssertFalse(canvas.contains("glassEffectID"))
    }

    func testToolbarUsesCompactVisibleHeightAndHeavyIcons() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(menu.contains("toolbarVisibleHeight"))
        XCTAssertTrue(menu.contains("toolbarSymbolFont"))
        XCTAssertTrue(metrics.contains("weight: .heavy"))
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
