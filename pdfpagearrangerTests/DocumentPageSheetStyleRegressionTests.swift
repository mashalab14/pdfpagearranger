import XCTest
@testable import pdfpagearranger
import CoreGraphics

final class DocumentPageSheetStyleRegressionTests: XCTestCase {
    func testPageSpacingIsTightAndNonOverlapping() {
        XCTAssertEqual(DocumentPageSheetStyle.pageSpacing(forContainerWidth: 100), 2, accuracy: 0.001)
        XCTAssertEqual(DocumentPageSheetStyle.pageSpacing(forContainerWidth: 390), 3.9, accuracy: 0.001)
        XCTAssertEqual(DocumentPageSheetStyle.pageSpacing(forContainerWidth: 800), 6, accuracy: 0.001)
        XCTAssertGreaterThan(DocumentPageSheetStyle.pageSpacing(forContainerWidth: 390), 0)
        XCTAssertLessThanOrEqual(DocumentPageSheetStyle.pageSpacing(forContainerWidth: 390), 6)
    }

    func testActiveAndInactivePagesShareIdenticalDisplaySize() {
        let imageSize = CGSize(width: 612, height: 792)
        let width = PageModeLayoutSizing.availableContentWidth(containerWidth: 393)
        let activeSize = PageModeLayoutSizing.displaySize(imageSize: imageSize, availableWidth: width)
        let inactiveSize = PageModeLayoutSizing.displaySize(imageSize: imageSize, availableWidth: width)

        XCTAssertEqual(activeSize.width, inactiveSize.width, accuracy: 0.001)
        XCTAssertEqual(activeSize.height, inactiveSize.height, accuracy: 0.001)
        XCTAssertEqual(PageModeLayoutSizing.horizontalMargin, DocumentPageSheetStyle.stackHorizontalMargin)
    }

    func testActivationDoesNotChangeLayoutFootprint() {
        let imageSize = CGSize(width: 792, height: 612)
        let before = PageModeLayoutSizing.displaySize(
            imageSize: imageSize,
            containerSize: CGSize(width: 430, height: 700)
        )
        // Halo is a shadow-only chrome; sizing API has no isActive parameter.
        let after = PageModeLayoutSizing.displaySize(
            imageSize: imageSize,
            containerSize: CGSize(width: 430, height: 700)
        )
        XCTAssertEqual(before.width, after.width, accuracy: 0.001)
        XCTAssertEqual(before.height, after.height, accuracy: 0.001)
    }

    func testActiveHaloConstantsAreSubtle() {
        XCTAssertGreaterThan(DocumentPageSheetStyle.activeHaloOpacity, 0)
        XCTAssertLessThanOrEqual(DocumentPageSheetStyle.activeHaloOpacity, 0.4)
        XCTAssertGreaterThan(DocumentPageSheetStyle.activeHaloRadius, DocumentPageSheetStyle.baseShadowRadius)
        XCTAssertGreaterThan(DocumentPageSheetStyle.baseShadowOpacity, 0)
        XCTAssertLessThan(DocumentPageSheetStyle.baseShadowOpacity, DocumentPageSheetStyle.activeHaloOpacity)
    }

    func testMixedOrientationsPreserveNaturalAspectAtEqualScaleRules() {
        let portrait = CGSize(width: 612, height: 792)
        let landscape = CGSize(width: 792, height: 612)
        let available = PageModeLayoutSizing.availableContentWidth(containerWidth: 393)

        let p = PageModeLayoutSizing.displaySize(imageSize: portrait, availableWidth: available)
        let l = PageModeLayoutSizing.displaySize(imageSize: landscape, availableWidth: available)

        XCTAssertEqual(p.width, l.width, accuracy: 0.001)
        XCTAssertNotEqual(p.height, l.height, accuracy: 0.001)
        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: portrait, displaySize: p))
        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: landscape, displaySize: l))
    }
}

final class DocumentPageSheetStyleSourceRegressionTests: XCTestCase {
    private func source(named fileName: String, subdirectory: String = "Views") throws -> String {
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

    func testSharedChromeAppliesHaloOnlyWhenActive() throws {
        let style = try source(named: "DocumentPageSheetStyle.swift", subdirectory: "Services")
        XCTAssertTrue(style.contains("documentPageSheetChrome(isActive:"))
        XCTAssertTrue(style.contains("activeHaloOpacity"))
        XCTAssertTrue(style.contains("Color.accentColor.opacity(isActive ?"))
        XCTAssertFalse(style.contains("strokeBorder"))
        XCTAssertFalse(style.contains("scaleEffect"))
    }

    func testHaloTransfersWithActivePageSlot() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("documentPageSheetChrome(isActive: isActive)"))
        XCTAssertTrue(pageEditor.contains("animation(.easeInOut(duration: 0.2), value: isActive)"))
        XCTAssertTrue(pageEditor.contains("accessibilityValue(isActive ? \"active\" : \"inactive\")"))
    }

    func testSearchAndOrganizerActivationReuseEqualScaleChrome() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("activatePage(id:"))
        XCTAssertTrue(pageEditor.contains("documentPageSheetChrome(isActive: isActive)"))
        XCTAssertTrue(pageEditor.contains(".frame(width: displaySize.width, height: displaySize.height)"))
        XCTAssertFalse(pageEditor.contains(".scaleEffect("))
    }

    func testPageMutationsDoNotIntroduceActiveScaleTransform() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("viewModel.rotatePage"))
        XCTAssertTrue(pageEditor.contains("viewModel.duplicatePage"))
        XCTAssertTrue(pageEditor.contains("viewModel.deletePage"))
        XCTAssertFalse(pageEditor.contains("scaleEffect(isActive"))
        XCTAssertFalse(pageEditor.contains("emphasizesActivePage"))
    }

    func testAddControlRemainsPresentAndDiscoverable() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("pageModeAddButton"))
        XCTAssertTrue(pageEditor.contains("floatingAddButton"))
        XCTAssertTrue(pageEditor.contains(".background(.ultraThinMaterial, in: Circle())"))
        XCTAssertTrue(pageEditor.contains("showAddSheet = true"))
        XCTAssertFalse(pageEditor.contains("Color.accentColor, in: Circle()"))
    }

    func testLightAndDarkModeUseSharedMaterialAndHaloTokens() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let style = try source(named: "DocumentPageSheetStyle.swift", subdirectory: "Services")
        XCTAssertTrue(pageEditor.contains(".background(.ultraThinMaterial, in: Capsule"))
        XCTAssertTrue(pageEditor.contains(".background(.ultraThinMaterial, in: Circle())"))
        XCTAssertTrue(style.contains("Color.accentColor.opacity"))
        XCTAssertFalse(pageEditor.contains(".background(.regularMaterial, in: Capsule"))
        XCTAssertFalse(style.contains("UIColor"))
    }
}
