import CoreGraphics
import UIKit
import XCTest
@testable import pdfpagearranger

final class SignaturePlacementEngineRegressionTests: XCTestCase {
    func testClampNormalizedCenterKeepsOverlayWithinPage() {
        let size = CGSize(width: 0.4, height: 0.2)
        let topLeft = OverlayInteractionEngine.clampNormalizedCenter(
            CGPoint(x: 0, y: 0),
            normalizedSize: size
        )
        XCTAssertEqual(topLeft.x, 0.2, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, 0.1, accuracy: 0.001)

        let bottomRight = OverlayInteractionEngine.clampNormalizedCenter(
            CGPoint(x: 1, y: 1),
            normalizedSize: size
        )
        XCTAssertEqual(bottomRight.x, 0.8, accuracy: 0.001)
        XCTAssertEqual(bottomRight.y, 0.9, accuracy: 0.001)
    }

    func testStoragePositionCentersOnTapPoint() {
        let image = PDFTestFactory.makeTestImage(size: CGSize(width: 200, height: 100))
        let normalizedSize = OverlayPlacementSizing.normalizedSignatureSize(
            image: image,
            pageAspectRatio: 612.0 / 792.0
        )
        let displaySize = CGSize(width: 300, height: 400)

        let position = SignaturePlacementEngine.storagePosition(
            forDisplayTap: CGPoint(x: 150, y: 200),
            displayPageSize: displaySize,
            normalizedOverlaySize: normalizedSize,
            pageRotation: 0
        )

        XCTAssertEqual(position.x, 0.5, accuracy: 0.02)
        XCTAssertEqual(position.y, 0.5, accuracy: 0.02)
    }

    func testStoragePositionClampsNearPageEdge() {
        let image = PDFTestFactory.makeTestImage(size: CGSize(width: 200, height: 100))
        let normalizedSize = OverlayPlacementSizing.normalizedSignatureSize(
            image: image,
            pageAspectRatio: 612.0 / 792.0
        )
        let displaySize = CGSize(width: 300, height: 400)

        let position = SignaturePlacementEngine.storagePosition(
            forDisplayTap: CGPoint(x: 5, y: 5),
            displayPageSize: displaySize,
            normalizedOverlaySize: normalizedSize,
            pageRotation: 0
        )

        XCTAssertGreaterThan(position.x, 0)
        XCTAssertGreaterThan(position.y, 0)
        XCTAssertLessThan(position.x, 0.5)
        XCTAssertLessThan(position.y, 0.5)
    }

    @MainActor
    func testAddSignatureOverlayAcceptsCustomPosition() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        defer { try? FileManager.default.removeItem(at: url) }
        await viewModel.importPDF(from: url)

        let page = try XCTUnwrap(viewModel.pages.first)
        let target = CGPoint(x: 0.25, y: 0.75)
        viewModel.addSignatureOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 0.77,
            at: target
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.position.x, target.x, accuracy: 0.001)
        XCTAssertEqual(overlay.position.y, target.y, accuracy: 0.001)
    }
}

final class SignatureTapPlacementUIRegressionTests: XCTestCase {
    func testPageEditorEntersSignaturePlacementMode() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("pendingSignatureImage"))
        XCTAssertTrue(source.contains("beginSignaturePlacement(image:"))
        XCTAssertTrue(source.contains("cancelSignaturePlacement()"))
        XCTAssertTrue(source.contains("signaturePlacementInstruction"))
        XCTAssertTrue(source.contains("Tap where you want to place the signature."))
        XCTAssertTrue(source.contains("placeSignature(atDisplayTap:"))
        XCTAssertTrue(source.contains("SignaturePlacementEngine.storagePosition"))
    }

    func testQuickSignatureEntersPlacementModeInsteadOfImmediatePlacement() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("beginSignaturePlacement(image: image)"))
        XCTAssertFalse(source.contains("placeSignature(image:"))
    }

    func testSignatureLibraryRoutesToPlacementMode() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("beginSignaturePlacement(image: image)"))
    }

    func testCanvasDisablesZoomSwipeAndOverlaySelectionDuringPlacement() throws {
        let source = try canvasSource()
        XCTAssertTrue(source.contains("signaturePlacementActive"))
        XCTAssertTrue(source.contains("!signaturePlacementActive"))
        XCTAssertTrue(source.contains("onSignaturePlacementTap"))
        XCTAssertTrue(source.contains("isInteractionEnabled: !signaturePlacementActive"))
    }

    func testCancelExitsPlacementWithoutAddingOverlay() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("signaturePlacementCancelButton"))
        XCTAssertTrue(source.contains("pendingSignatureImage = nil"))
    }

    func testPlacementUsesSharedRegistrationPath() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("registerNewOverlayPlacement(overlayID: overlayID)"))
        XCTAssertTrue(source.contains("OverlayPlacementFeedback.playPlacementHaptic()"))
    }

    private func pageEditorSource() throws -> String {
        try projectSource(named: "PageEditorView.swift", subdirectory: "Views")
    }

    private func canvasSource() throws -> String {
        try projectSource(named: "PageOverlayCanvasView.swift", subdirectory: "Views")
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
