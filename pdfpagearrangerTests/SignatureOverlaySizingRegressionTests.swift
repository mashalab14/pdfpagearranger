import PDFKit
import PencilKit
import UIKit
import XCTest
@testable import pdfpagearranger

final class OverlayPlacementSizingTests: XCTestCase {
    private let pageAspectRatio: CGFloat = 612.0 / 792.0

    func testSignatureFrameAspectMatchesPNGAspectRatio() {
        let image = makeTestImage(size: CGSize(width: 331, height: 12))
        let normalized = OverlayPlacementSizing.normalizedSignatureSize(
            image: image,
            pageAspectRatio: pageAspectRatio
        )

        let frameAspect = OverlayPlacementSizing.frameAspectRatio(
            normalizedSize: normalized,
            pageAspectRatio: pageAspectRatio
        )
        XCTAssertEqual(frameAspect, OverlayPlacementSizing.imageAspectRatio(for: image), accuracy: 0.001)
    }

    func testScaledToFitHasNoLetterboxingForMatchedSignatureFrame() {
        let image = makeTestImage(size: CGSize(width: 331, height: 12))
        let normalized = OverlayPlacementSizing.normalizedSignatureSize(
            image: image,
            pageAspectRatio: pageAspectRatio
        )
        let pageWidth: CGFloat = 390
        let pageHeight: CGFloat = 504
        let frame = CGSize(
            width: normalized.width * pageWidth,
            height: normalized.height * pageHeight
        )

        let ratio = OverlayPlacementSizing.scaledToFitHeightRatio(frameSize: frame, imageSize: image.size)
        XCTAssertEqual(ratio, 1.0, accuracy: 0.001)
    }

    func testImageOverlaySizingUsesLegacyFormula() {
        let image = makeTestImage(size: CGSize(width: 200, height: 100))
        let imageAspect = image.size.width / image.size.height
        let expectedHeight = min((0.35 / imageAspect) / pageAspectRatio, 0.6)

        let normalized = OverlayPlacementSizing.normalizedImageSize(
            image: image,
            pageAspectRatio: pageAspectRatio
        )

        XCTAssertEqual(normalized.width, 0.35, accuracy: 0.001)
        XCTAssertEqual(normalized.height, expectedHeight, accuracy: 0.001)
    }

    private func makeTestImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }
}

@MainActor
final class SignatureOverlaySizingRegressionTests: XCTestCase {
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

    private let pageAspectRatio: CGFloat = 612.0 / 792.0

    func testPlacedSignatureAspectRatioMatchesSavedPNG() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let image = sampleImage(.horizontal)
        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: pageAspectRatio)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let frameAspect = OverlayPlacementSizing.frameAspectRatio(
            normalizedSize: overlay.size,
            pageAspectRatio: pageAspectRatio
        )
        XCTAssertEqual(frameAspect, OverlayPlacementSizing.imageAspectRatio(for: image), accuracy: 0.001)
    }

    func testHorizontalSignatureFrameIsNotMuchTallerThanDisplay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let image = sampleImage(.horizontal)
        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: pageAspectRatio)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let frame = physicalFrameSize(for: overlay.size)
        let letterboxRatio = OverlayPlacementSizing.scaledToFitHeightRatio(frameSize: frame, imageSize: image.size)

        XCTAssertGreaterThan(letterboxRatio, 0.99)
        XCTAssertLessThan(frame.height / (frame.width / image.size.width * image.size.height), 1.05)
    }

    func testTallLoopingSignaturePreservesAspectRatio() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let image = sampleImage(.tallLoop)
        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: pageAspectRatio)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        assertSignatureMatchesImageAspect(overlay: overlay, image: image)
    }

    func testSmallLightSignaturePreservesAspectRatio() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let image = sampleImage(.smallLight)
        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: pageAspectRatio)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        assertSignatureMatchesImageAspect(overlay: overlay, image: image)
    }

    func testSelectionBorderUsesOverlayFrameDimensions() throws {
        let source = try imageOverlayViewSource()
        XCTAssertTrue(source.contains(".frame(width: activeLayoutSize.width, height: activeLayoutSize.height)"))
        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: 4)"))
        XCTAssertTrue(source.contains(".scaledToFit()"))
    }

    func testSignatureResizeStillPreservesAspectRatio() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Services/OverlayInteractionEngine.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("uniformResizedLayoutSize"))
        XCTAssertTrue(source.contains("magnificationResizedNormalizedSize"))
    }

    func testImageOverlaySizingIsUnchanged() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let image = PDFTestFactory.makeTestImage()
        viewModel.addImageOverlay(to: page.id, image: image, pageAspectRatio: pageAspectRatio)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let expected = OverlayPlacementSizing.normalizedImageSize(
            image: image,
            pageAspectRatio: pageAspectRatio
        )

        XCTAssertEqual(overlay.size.width, expected.width, accuracy: 0.001)
        XCTAssertEqual(overlay.size.height, expected.height, accuracy: 0.001)
    }

    func testExportStillIncludesSignatures() async throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)

        let exportedDocument = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertEqual(exportedDocument.pageCount, 1)
        XCTAssertNotNil(exportedDocument.page(at: 0))
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testViewModelUsesSignatureSpecificSizing() throws {
        let source = try viewModelSource()
        XCTAssertTrue(source.contains("OverlayPlacementSizing.normalizedSignatureSize"))
        XCTAssertTrue(source.contains("OverlayPlacementSizing.normalizedImageSize"))
    }

    private enum SampleImageKind {
        case horizontal
        case tallLoop
        case smallLight
    }

    private func sampleImage(_ kind: SampleImageKind) -> UIImage {
        let drawing: PKDrawing
        switch kind {
        case .horizontal:
            drawing = SignatureSizingTestDrawings.longHorizontal()
        case .tallLoop:
            drawing = SignatureSizingTestDrawings.tallLoop()
        case .smallLight:
            drawing = SignatureSizingTestDrawings.smallLight()
        }
        return SignatureRenderer.image(from: drawing) ?? OverlayTestFactory.makeSignatureImage()
    }

    private func physicalFrameSize(for normalizedSize: CGSize) -> CGSize {
        CGSize(
            width: normalizedSize.width * 612,
            height: normalizedSize.height * 792
        )
    }

    private func assertSignatureMatchesImageAspect(overlay: PageObject, image: UIImage, file: StaticString = #filePath, line: UInt = #line) {
        let frameAspect = OverlayPlacementSizing.frameAspectRatio(
            normalizedSize: overlay.size,
            pageAspectRatio: pageAspectRatio
        )
        XCTAssertEqual(
            frameAspect,
            OverlayPlacementSizing.imageAspectRatio(for: image),
            accuracy: 0.001,
            file: file,
            line: line
        )

        let frame = physicalFrameSize(for: overlay.size)
        let letterboxRatio = OverlayPlacementSizing.scaledToFitHeightRatio(frameSize: frame, imageSize: image.size)
        XCTAssertEqual(letterboxRatio, 1.0, accuracy: 0.001, file: file, line: line)
    }

    private func imageOverlayViewSource() throws -> String {
        try projectSource(named: "ImageOverlayObjectView.swift", subdirectory: "Views")
    }

    private func viewModelSource() throws -> String {
        try projectSource(named: "PDFEditorViewModel.swift", subdirectory: "ViewModels")
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

private enum SignatureSizingTestDrawings {
    static func longHorizontal() -> PKDrawing {
        stroke(center: CGPoint(x: 200, y: 150), span: 320, strokeWidth: 3)
    }

    static func tallLoop() -> PKDrawing {
        let radius: CGFloat = 55
        var points: [PKStrokePoint] = []
        for index in 0...24 {
            let t = CGFloat(index) / 24.0 * .pi * 2
            points.append(PKStrokePoint(
                location: CGPoint(x: 200 + cos(t) * radius, y: 150 + sin(t) * radius * 1.4),
                timeOffset: TimeInterval(index) * 0.02,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ))
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }

    static func smallLight() -> PKDrawing {
        stroke(center: CGPoint(x: 200, y: 150), span: 120, strokeWidth: 2)
    }

    private static func stroke(center: CGPoint, span: CGFloat, strokeWidth: CGFloat) -> PKDrawing {
        let halfSpan = span / 2
        let points = [
            PKStrokePoint(location: CGPoint(x: center.x - halfSpan, y: center.y + 2), timeOffset: 0,
                          size: CGSize(width: strokeWidth, height: strokeWidth), opacity: 1, force: 1, azimuth: 0, altitude: 0),
            PKStrokePoint(location: CGPoint(x: center.x, y: center.y - 2), timeOffset: 0.05,
                          size: CGSize(width: strokeWidth, height: strokeWidth), opacity: 1, force: 1, azimuth: 0, altitude: 0),
            PKStrokePoint(location: CGPoint(x: center.x + halfSpan, y: center.y + 1), timeOffset: 0.1,
                          size: CGSize(width: strokeWidth, height: strokeWidth), opacity: 1, force: 1, azimuth: 0, altitude: 0),
        ]
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }
}
