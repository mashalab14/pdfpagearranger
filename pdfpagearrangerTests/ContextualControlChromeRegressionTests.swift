import XCTest
@testable import pdfpagearranger

final class ContextualGlassContainerRegressionTests: XCTestCase {
    func testSharedGlassContainerUsedBySignatureToolbar() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualGlassContainer()"))
        XCTAssertTrue(menu.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(menu.contains("Color.white.opacity"))
    }

    func testSharedGlassContainerUsedBySignatureEditPopover() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("contextualGlassContainer("))
        XCTAssertTrue(popover.contains("contextualExpandedTapTarget"))
        XCTAssertFalse(popover.contains(".background(.regularMaterial"))
    }

    func testContextualGlassContainerUsesCapsuleGlass() throws {
        let container = try projectSource(named: "ContextualGlassContainer.swift", subdirectory: "Views")
        XCTAssertTrue(container.contains("glassEffect(.regular, in: .capsule)"))
        XCTAssertTrue(container.contains("Capsule()"))
        XCTAssertTrue(container.contains("contextualExpandedTapTarget"))
    }

    func testToolbarUsesCompactVisibleHeightAndBoldIcons() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        let metrics = try projectSource(named: "ContextualControlMetrics.swift", subdirectory: "Models")
        XCTAssertTrue(menu.contains("toolbarVisibleHeight"))
        XCTAssertTrue(menu.contains("toolbarSymbolFont"))
        XCTAssertTrue(metrics.contains("weight: .bold"))
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
