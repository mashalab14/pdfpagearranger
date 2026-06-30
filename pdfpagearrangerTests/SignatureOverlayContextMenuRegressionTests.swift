import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class SignatureOverlayMenuEngineRegressionTests: XCTestCase {
    func testAnchorPointClampsWithinPageBounds() {
        let layout = OverlayGeometryEngine.Layout(
            center: CGPoint(x: 10, y: 10),
            size: CGSize(width: 20, height: 20),
            rotationDegrees: 0
        )
        let pageSize = CGSize(width: 300, height: 400)

        let anchor = SignatureOverlayMenuEngine.anchorPoint(for: layout, pageSize: pageSize)

        XCTAssertGreaterThanOrEqual(anchor.x, SignatureOverlayMenuEngine.menuWidth / 2 + 8)
        XCTAssertLessThanOrEqual(
            anchor.x,
            pageSize.width - SignatureOverlayMenuEngine.menuWidth / 2 - 8
        )
        XCTAssertGreaterThanOrEqual(anchor.y, SignatureOverlayMenuEngine.minimumTopPadding)
    }

    func testAnchorPointSitsAboveOverlayBounds() {
        let layout = OverlayGeometryEngine.Layout(
            center: CGPoint(x: 150, y: 200),
            size: CGSize(width: 80, height: 40),
            rotationDegrees: 0
        )
        let pageSize = CGSize(width: 300, height: 400)

        let anchor = SignatureOverlayMenuEngine.anchorPoint(for: layout, pageSize: pageSize)

        XCTAssertLessThan(anchor.y, layout.topLeftBounds.minY)
    }
}

final class SignatureOverlayContextMenuUIRegressionTests: XCTestCase {
    func testCanvasShowsSignatureContextMenuForSelectedSignatureOnly() throws {
        let canvas = try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
        XCTAssertTrue(canvas.contains("selectedSignatureOverlay"))
        XCTAssertTrue(canvas.contains("showsSignatureContextMenu"))
        XCTAssertTrue(canvas.contains("SignatureOverlayContextMenu"))
        XCTAssertTrue(canvas.contains("overlayManipulationState.isActive"))
        XCTAssertTrue(canvas.contains("onEditSignature"))
    }

    func testSignatureMenuUsesIconActionsAndAccessibilityLabels() throws {
        let menu = try projectSource(named: "SignatureOverlayContextMenu.swift", subdirectory: "Views")
        XCTAssertTrue(menu.contains("pencil"))
        XCTAssertTrue(menu.contains("trash"))
        XCTAssertTrue(menu.contains("ellipsis"))
        XCTAssertTrue(menu.contains("Edit Signature"))
        XCTAssertTrue(menu.contains("Delete Signature"))
        XCTAssertTrue(menu.contains("More Signature Actions"))
        XCTAssertTrue(menu.contains("signatureOverlayContextMenu"))
        XCTAssertTrue(menu.contains("Duplicate"))
        XCTAssertTrue(menu.contains("Bring Forward"))
    }

    func testSignatureOverlaysHideInlineDeleteControl() throws {
        let overlayView = try projectSource(named: "ImageOverlayObjectView.swift", subdirectory: "Views")
        XCTAssertTrue(overlayView.contains("object.type != .signature"))
    }

    func testEditPlacedSignatureSheetShowsRequiredSections() throws {
        let sheet = try projectSource(named: "EditPlacedSignatureSheet.swift", subdirectory: "Views")
        XCTAssertTrue(sheet.contains("Edit Signature"))
        XCTAssertTrue(sheet.contains("Color"))
        XCTAssertTrue(sheet.contains("Thickness"))
        XCTAssertTrue(sheet.contains("Reset"))
        XCTAssertTrue(sheet.contains("Save to Library"))
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
