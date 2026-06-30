import XCTest
@testable import pdfpagearranger

final class OverlayPlacementAnimationRegressionTests: XCTestCase {
    func testPlacementAnimationUsesSubtleScaleAndFade() {
        XCTAssertEqual(OverlayPlacementAnimation.duration, 0.15, accuracy: 0.001)
        XCTAssertEqual(OverlayPlacementAnimation.initialScale, 0.95, accuracy: 0.001)
        XCTAssertEqual(OverlayPlacementAnimation.scale(for: 0), 0.95, accuracy: 0.001)
        XCTAssertEqual(OverlayPlacementAnimation.scale(for: 1), 1.0, accuracy: 0.001)
    }

    func testPlacementFeedbackUsesLightImpactHaptic() throws {
        let source = try projectSource(named: "OverlayPlacementFeedback.swift", subdirectory: "Services")
        XCTAssertTrue(source.contains("UIImpactFeedbackGenerator"))
        XCTAssertTrue(source.contains("style: .light"))
        XCTAssertTrue(source.contains("impactOccurred()"))
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

@MainActor
final class OverlayPlacementUIRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        viewModel = nil
        try await super.tearDown()
    }

    func testNewlyPlacedSignatureCanBeAutoSelected() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            image: OverlayTestFactory.makeSignatureImage(),
            pageAspectRatio: 0.77
        )

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.id, overlayID)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.type, .signature)
    }

    func testNewlyPlacedImageReturnsOverlayID() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 0.77
        )

        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.id, overlayID)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.type, .image)
    }

    func testImageOverlayViewDefinesPlacementAnimationState() throws {
        let source = try imageOverlaySource()
        XCTAssertTrue(source.contains("animatePlacement"))
        XCTAssertTrue(source.contains("placementReveal"))
        XCTAssertTrue(source.contains("OverlayPlacementAnimation.scale(for: placementReveal)"))
        XCTAssertTrue(source.contains("startPlacementAnimationIfNeeded"))
        XCTAssertTrue(source.contains("didStartPlacementAnimation"))
    }

    func testPageEditorTracksPlacementAnimatingOverlayIDs() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("placementAnimatingOverlayIDs"))
        XCTAssertTrue(source.contains("registerNewOverlayPlacement"))
        XCTAssertTrue(source.contains("OverlayPlacementFeedback.playPlacementHaptic()"))
        XCTAssertTrue(source.contains("placementAnimatingOverlayIDs.removeAll()"))
    }

    func testPageOverlayCanvasPassesPlacementAnimationOnlyForTrackedIDs() throws {
        let source = try pageOverlayCanvasSource()
        XCTAssertTrue(source.contains("placementAnimatingOverlayIDs"))
        XCTAssertTrue(source.contains("placementAnimatingOverlayIDs.contains(object.id)"))
        XCTAssertTrue(source.contains("onPlacementAnimationFinished"))
    }

    func testExistingOverlaysDoNotAnimateWhenReopeningPageMode() throws {
        let pageEditor = try pageEditorSource()
        XCTAssertTrue(pageEditor.contains("placementAnimatingOverlayIDs: Set<UUID> = []"))
        XCTAssertTrue(pageEditor.contains("placementAnimatingOverlayIDs.removeAll()"))

        let overlayView = try imageOverlaySource()
        XCTAssertTrue(overlayView.contains("guard animatePlacement, !didStartPlacementAnimation"))
        XCTAssertTrue(overlayView.contains("if !animatePlacement"))
    }

    func testQuickSignaturePlacementStillUsesSharedRegistrationPath() throws {
        let source = try pageEditorSource()
        XCTAssertTrue(source.contains("registerNewOverlayPlacement(overlayID: overlayID)"))
        XCTAssertTrue(source.contains("handleQuickSignature"))
        XCTAssertTrue(source.contains("beginSignaturePlacement"))
    }

    private func imageOverlaySource() throws -> String {
        try projectSource(named: "ImageOverlayObjectView.swift", subdirectory: "Views")
    }

    private func pageEditorSource() throws -> String {
        try projectSource(named: "PageEditorView.swift", subdirectory: "Views")
    }

    private func pageOverlayCanvasSource() throws -> String {
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
