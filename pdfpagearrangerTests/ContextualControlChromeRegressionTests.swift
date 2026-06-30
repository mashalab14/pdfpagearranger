import XCTest
@testable import pdfpagearranger

final class ContextualControlChromeRegressionTests: XCTestCase {
    func testSharedChromeModifierUsedBySignatureToolbar() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("contextualControlChrome()"))
        XCTAssertFalse(menu.contains("Capsule()"))
        XCTAssertFalse(menu.contains("Color.white.opacity"))
    }

    func testSharedChromeModifierUsedBySignatureEditPopover() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("contextualControlChrome()"))
        XCTAssertFalse(popover.contains(".background(.regularMaterial"))
    }

    func testContextualControlChromeDefinesSharedContainerStyle() throws {
        let chrome = try projectSource(named: "ContextualControlChrome.swift", subdirectory: "Views")
        XCTAssertTrue(chrome.contains("regularMaterial"))
        XCTAssertTrue(chrome.contains("ContextualControlMetrics.cornerRadius"))
        XCTAssertTrue(chrome.contains("strokeBorder"))
        XCTAssertTrue(chrome.contains("shadow"))
    }

    func testToolbarIconsUseSemiboldSymbolWeight() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("ContextualControlMetrics.symbolFont.weight(ContextualControlMetrics.symbolWeight)"))
        XCTAssertTrue(menu.contains("symbolWeight"))
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
