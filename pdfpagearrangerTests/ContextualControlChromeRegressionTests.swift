import XCTest
@testable import pdfpagearranger

final class ContextualGlassContainerRegressionTests: XCTestCase {
    func testSharedGlassContainerUsedBySignatureToolbar() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualGlassContainer()"))
        XCTAssertTrue(menu.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(menu.contains("Color.white.opacity"))
    }

    func testSignatureEditPopoverUsesRoundedRectangleGlass() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("contextualGlassContainer("))
        XCTAssertTrue(popover.contains(".roundedRectangle(cornerRadius: ContextualControlMetrics.popoverCornerRadius)"))
        XCTAssertTrue(popover.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(popover.contains(".background(.regularMaterial"))
    }

    func testContextualGlassContainerSupportsCapsuleAndRoundedRectangle() throws {
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        XCTAssertTrue(container.contains("case capsule"))
        XCTAssertTrue(container.contains("case roundedRectangle"))
        XCTAssertTrue(container.contains("glassEffect(.regular, in: .capsule)"))
        XCTAssertTrue(container.contains(".rect(cornerRadius: cornerRadius, style: .continuous)"))
        XCTAssertTrue(container.contains("contextualExpandedTapTarget"))
    }

    func testToolbarUsesCompactVisibleHeightAndBoldIcons() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(menu.contains("toolbarVisibleHeight"))
        XCTAssertTrue(menu.contains("toolbarSymbolFont"))
        XCTAssertTrue(metrics.contains("weight: .bold"))
        XCTAssertTrue(metrics.contains("toolbarShadowOpacity"))
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
