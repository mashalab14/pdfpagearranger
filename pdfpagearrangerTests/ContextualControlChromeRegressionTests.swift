import XCTest
@testable import pdfpagearranger

final class ContextualGlassContainerRegressionTests: XCTestCase {
    func testSharedGlassContainerUsedBySignatureToolbar() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualGlassContainer()"))
        XCTAssertFalse(menu.contains("Capsule()"))
        XCTAssertFalse(menu.contains("Color.white.opacity"))
        XCTAssertFalse(menu.contains("contextualControlChrome()"))
    }

    func testSharedGlassContainerUsedBySignatureEditPopover() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("contextualGlassContainer()"))
        XCTAssertFalse(popover.contains(".background(.regularMaterial"))
        XCTAssertFalse(popover.contains("contextualControlChrome()"))
    }

    func testSharedGlassContainerUsedByPDFTextSelectionMenu() throws {
        let menu = try projectSource(named: "PDFTextSelectionContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualGlassContainer("))
        XCTAssertFalse(menu.contains(".background(.regularMaterial"))
    }

    func testContextualGlassContainerDefinesLiquidGlassStyle() throws {
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        XCTAssertTrue(container.contains("glassEffect"))
        XCTAssertTrue(container.contains("ContextualControlMetrics.glassCornerRadius"))
        XCTAssertTrue(container.contains("LinearGradient"))
        XCTAssertTrue(container.contains("shadow"))
        XCTAssertTrue(container.contains("contextualGlass"))
    }

    func testCanvasAnimatesContextualGlassControls() throws {
        let canvas = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertTrue(canvas.contains("GlassEffectContainer"))
        XCTAssertTrue(canvas.contains("glassEffectID"))
        XCTAssertTrue(canvas.contains("ContextualGlassAnimation.presentation"))
        XCTAssertTrue(canvas.contains(".transition(.contextualGlass)"))
    }

    func testToolbarIconsUseSemiboldSymbolWeight() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("ContextualControlMetrics.symbolFont.weight(ContextualControlMetrics.symbolWeight)"))
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
