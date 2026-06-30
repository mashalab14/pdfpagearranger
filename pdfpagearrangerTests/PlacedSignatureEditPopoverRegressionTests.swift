import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class SignatureEditPopoverEngineRegressionTests: XCTestCase {
    func testAnchorPointPrefersAboveSignature() {
        let layout = OverlayGeometryEngine.Layout(
            center: CGPoint(x: 150, y: 200),
            size: CGSize(width: 80, height: 40),
            rotationDegrees: 0
        )
        let pageSize = CGSize(width: 300, height: 400)

        let anchor = SignatureEditPopoverEngine.anchorPoint(for: layout, pageSize: pageSize)

        XCTAssertLessThan(anchor.y, layout.topLeftBounds.minY)
    }

    func testAnchorPointFallsBackBelowWhenNearTopEdge() {
        let layout = OverlayGeometryEngine.Layout(
            center: CGPoint(x: 150, y: 20),
            size: CGSize(width: 80, height: 30),
            rotationDegrees: 0
        )
        let pageSize = CGSize(width: 300, height: 400)

        let anchor = SignatureEditPopoverEngine.anchorPoint(for: layout, pageSize: pageSize)

        XCTAssertGreaterThan(anchor.y, layout.topLeftBounds.maxY)
    }

    func testAnchorPointClampsHorizontallyWithinPage() {
        let layout = OverlayGeometryEngine.Layout(
            center: CGPoint(x: 10, y: 200),
            size: CGSize(width: 20, height: 20),
            rotationDegrees: 0
        )
        let pageSize = CGSize(width: 420, height: 400)
        let popoverSize = SignatureEditPopoverEngine.popoverSize

        let anchor = SignatureEditPopoverEngine.anchorPoint(for: layout, pageSize: pageSize)

        XCTAssertGreaterThanOrEqual(anchor.x, popoverSize.width / 2 + SignatureEditPopoverEngine.edgePadding)
        XCTAssertLessThanOrEqual(
            anchor.x,
            pageSize.width - popoverSize.width / 2 - SignatureEditPopoverEngine.edgePadding
        )
    }
}

final class PlacedSignatureEditPopoverUIRegressionTests: XCTestCase {
    func testPopoverUsesTwoRowMarkupControls() throws {
        let popover = try projectSource(named: "PlacedSignatureEditPopover.swift", subdirectory: "Views")
        XCTAssertTrue(popover.contains("placedSignatureEditPopover"))
        XCTAssertTrue(popover.contains("VStack(spacing: ContextualControlMetrics.popoverRowSpacing)"))
        XCTAssertTrue(popover.contains("thicknessRowPaletteColumns"))
        XCTAssertTrue(popover.contains("thicknessRowMinusColumns"))
        XCTAssertTrue(popover.contains("thicknessRowLabelColumns"))
        XCTAssertTrue(popover.contains("thicknessRowPlusColumns"))
        XCTAssertTrue(popover.contains("contextualGlassContainer()"))
        XCTAssertTrue(popover.contains("SignatureInkColor.presetDisplayOrder"))
        XCTAssertTrue(popover.contains("paintpalette.fill"))
        XCTAssertTrue(popover.contains("SignatureUIColorPicker"))
        XCTAssertTrue(popover.contains("signatureEditThicknessMinus"))
        XCTAssertTrue(popover.contains("signatureEditThicknessPlus"))
        XCTAssertTrue(popover.contains("PlacedSignatureStrokeWidth.label"))
        XCTAssertTrue(popover.contains("PlacedSignatureStrokeWidth.decreased"))
        XCTAssertTrue(popover.contains("PlacedSignatureStrokeWidth.increased"))
        XCTAssertTrue(popover.contains("ContextualControlMetrics.minimumTapTarget"))
        XCTAssertTrue(popover.contains("allowsHitTesting(false)"))
        XCTAssertTrue(popover.contains("presetColorDiameter"))
        XCTAssertFalse(popover.contains("Done"))
        XCTAssertFalse(popover.contains("navigationTitle"))
        XCTAssertFalse(popover.contains("presentationDetents"))
    }

    func testCanvasHostsFloatingEditPopoverNotSheet() throws {
        let canvas = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertTrue(canvas.contains("PlacedSignatureEditPopover"))
        XCTAssertTrue(canvas.contains("signatureEditOverlayID"))
        XCTAssertTrue(canvas.contains("SignatureEditPopoverEngine.anchorPoint"))
        XCTAssertFalse(canvas.contains("EditPlacedSignatureSheet"))
    }

    func testPageEditorDoesNotPresentEditSheet() throws {
        let editor = try projectSource(named: "PageEditorView.swift", subdirectory: "Views")
        XCTAssertTrue(editor.contains("signatureEditOverlayID"))
        XCTAssertFalse(editor.contains("EditPlacedSignatureSheet"))
        XCTAssertFalse(editor.contains("editPlacedSignatureSheet"))
    }

    func testMoreMenuHostsResetAndSaveToLibrary() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("Reset"))
        XCTAssertTrue(menu.contains("Save to Library"))
        XCTAssertTrue(menu.contains("signatureMenuReset"))
        XCTAssertTrue(menu.contains("signatureMenuSaveToLibrary"))
        XCTAssertTrue(menu.contains("showReset"))
        XCTAssertTrue(menu.contains("showSaveToLibrary"))
    }

    func testAdvancedColorUsesNativeUIColorPicker() throws {
        let picker = try projectSource(named: "SignatureUIColorPicker.swift", subdirectory: "Views")
        XCTAssertTrue(picker.contains("UIColorPickerViewController"))
        XCTAssertTrue(picker.contains("supportsAlpha = true"))
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
