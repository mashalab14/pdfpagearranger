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

    func testIsDisplayTapInsidePageAcceptsBoundsAndRejectsOutside() {
        let displaySize = CGSize(width: 300, height: 400)

        XCTAssertTrue(
            SignaturePlacementEngine.isDisplayTapInsidePage(
                CGPoint(x: 0, y: 0),
                displayPageSize: displaySize
            )
        )
        XCTAssertTrue(
            SignaturePlacementEngine.isDisplayTapInsidePage(
                CGPoint(x: 300, y: 400),
                displayPageSize: displaySize
            )
        )
        XCTAssertFalse(
            SignaturePlacementEngine.isDisplayTapInsidePage(
                CGPoint(x: -1, y: 200),
                displayPageSize: displaySize
            )
        )
        XCTAssertFalse(
            SignaturePlacementEngine.isDisplayTapInsidePage(
                CGPoint(x: 301, y: 200),
                displayPageSize: displaySize
            )
        )
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
    func testPageEditorSilentlyArmsSignaturePlacement() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("pendingSignaturePlacement"))
        XCTAssertTrue(source.contains("beginSignaturePlacement(context:"))
        XCTAssertTrue(source.contains("handleQuickSignature()"))
        XCTAssertTrue(source.contains("placeSignature(atDisplayTap:"))
        XCTAssertTrue(source.contains("SignaturePlacementEngine.storagePosition"))
        XCTAssertTrue(source.contains("SignaturePlacementEngine.isDisplayTapInsidePage"))
        XCTAssertFalse(source.contains("signaturePlacementInstruction"))
        XCTAssertFalse(source.contains("Tap where you want to place the signature."))
        XCTAssertFalse(source.contains("signaturePlacementCancelButton"))
    }

    func testQuickSignatureArmsPlacementInsteadOfImmediatePlacement() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("beginSignaturePlacement(\n                context:"))
        XCTAssertFalse(source.contains("placeSignature(image:"))
    }

    func testSignatureLibraryRoutesToSilentPlacement() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("beginSignaturePlacement(context: context)"))
    }

    func testCanvasRoutesPageTapsToPlacementPath() throws {
        let source = try canvasSource()
        XCTAssertTrue(source.contains("signaturePlacementActive"))
        XCTAssertTrue(source.contains("onSignaturePlacementTap"))
        XCTAssertTrue(source.contains("onSignaturePlacementDismiss"))
        XCTAssertTrue(source.contains("handlePageTap(at:"))
        XCTAssertTrue(source.contains("handleCanvasBackgroundTap()"))
        XCTAssertTrue(source.contains("SignaturePlacementEngine.isDisplayTapInsidePage"))
        XCTAssertTrue(source.contains("isInteractionEnabled: !signaturePlacementActive"))
    }

    func testCanvasBlocksTextSelectionWhilePlacementArmed() throws {
        let source = try canvasSource()
        XCTAssertTrue(source.contains("guard !signaturePlacementActive else { return }"))
        XCTAssertTrue(source.contains("!signaturePlacementActive"))
        XCTAssertTrue(source.contains("isInteractionEnabled: !signaturePlacementActive"))
    }

    func testPlacementClearsAfterSuccessfulRegistration() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("pendingSignaturePlacement = nil"))
        XCTAssertTrue(source.contains("registerNewOverlayPlacement(overlayID: overlayID)"))
        XCTAssertTrue(source.contains("OverlayPlacementFeedback.playPlacementHaptic()"))
    }

    func testAddBarRemainsVisibleDuringPlacement() throws {
        let source = try pageEditorSource()
        // Signature placement must not hide the page bottom toolbar / Add entry point.
        XCTAssertTrue(source.contains("pageBottomToolbar"))
        XCTAssertTrue(source.contains("pageModeAddButton"))
        XCTAssertFalse(source.contains("if !signaturePlacementActive {\n                pageBottomToolbar"))
        XCTAssertFalse(source.contains("if !signaturePlacementActive {\n                addButtonBar"))
        // Only text editing gates the toolbar; placement modes keep Add available.
        XCTAssertTrue(source.contains("if !textEditingActive {\n                pageBottomToolbar\n            }"))
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
