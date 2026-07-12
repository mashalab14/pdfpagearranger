import CoreGraphics
import PDFKit
import UIKit
import XCTest
@testable import pdfpagearranger

final class WatermarkLayerRegressionTests: XCTestCase {
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []

    override func setUp() {
        super.setUp()
        pdfService = PDFService()
    }

    override func tearDown() {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        pdfService = nil
        super.tearDown()
    }

    func testDefaultLayerIsAboveContent() {
        XCTAssertEqual(WatermarkSettings.default.layer, .aboveContent)
    }

    func testUserCanChooseBehindContentLayer() {
        var settings = WatermarkSettings.default
        settings.layer = .behindContent
        XCTAssertEqual(settings.layer, .behindContent)
    }

    func testAboveContentDrawOrderInExportSource() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "PDFService.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        let pageDrawRange = try XCTUnwrap(source.range(of: "sourcePage.draw(with: .mediaBox, to: context)"))
        let aboveWatermarkRange = try XCTUnwrap(
            source.range(of: "watermarkSettings.layer == .aboveContent")
        )
        XCTAssertLessThan(pageDrawRange.lowerBound, aboveWatermarkRange.lowerBound)
    }

    func testBehindContentDrawOrderInExportSource() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "PDFService.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        let behindWatermarkRange = try XCTUnwrap(
            source.range(of: "watermarkSettings.layer == .behindContent")
        )
        let pageDrawRange = try XCTUnwrap(source.range(of: "sourcePage.draw(with: .mediaBox, to: context)"))
        XCTAssertLessThan(behindWatermarkRange.lowerBound, pageDrawRange.lowerBound)
    }

    func testWatermarkStillDrawsBeforeOverlaysRegardlessOfLayer() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "PDFService.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        let overlayRange = try XCTUnwrap(source.range(of: "OverlayPDFExporter.drawOverlays"))
        let behindRange = try XCTUnwrap(source.range(of: "watermarkSettings.layer == .behindContent"))
        let aboveRange = try XCTUnwrap(source.range(of: "watermarkSettings.layer == .aboveContent"))
        XCTAssertLessThan(behindRange.lowerBound, overlayRange.lowerBound)
        XCTAssertLessThan(aboveRange.lowerBound, overlayRange.lowerBound)
    }

    func testPreviewRendererUsesLayerSwitch() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("switch settings.layer"))
        XCTAssertTrue(source.contains("case .aboveContent"))
        XCTAssertTrue(source.contains("case .behindContent"))
    }

    func testThumbnailServiceUsesSharedWatermarkCompositor() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "ThumbnailService.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("WatermarkRenderer.compositeOnImage"))
    }

    func testPageRenderServiceUsesSharedWatermarkCompositor() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "PageRenderService.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("WatermarkRenderer.compositeOnImage"))
    }

    func testBehindContentPreviewCompositesPageAboveWatermark() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        guard let behindStart = source.range(of: "case .behindContent:")?.lowerBound else {
            XCTFail("Missing behind content branch")
            return
        }
        let behindSection = String(source[behindStart...])
        let watermarkDraw = try XCTUnwrap(behindSection.range(of: "drawWatermarkContent"))
        let pageDraw = try XCTUnwrap(behindSection.range(of: "pageImage.draw(at: .zero)"))
        XCTAssertLessThan(watermarkDraw.lowerBound, pageDraw.lowerBound)
    }

    func testAboveContentPreviewCompositesWatermarkAbovePage() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        guard let aboveStart = source.range(of: "case .aboveContent:")?.lowerBound else {
            XCTFail("Missing above content branch")
            return
        }
        let aboveSection = String(source[aboveStart...])
        let pageDraw = try XCTUnwrap(aboveSection.range(of: "pageImage.draw(at: .zero)"))
        let watermarkDraw = try XCTUnwrap(aboveSection.range(of: "drawWatermarkContent"))
        XCTAssertLessThan(pageDraw.lowerBound, watermarkDraw.lowerBound)
    }

    func testLayerGeometryUsesSharedEngine() throws {
        let above = watermarkSettings(layer: .aboveContent)
        let behind = watermarkSettings(layer: .behindContent)
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        let aboveLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: above,
            pageRotation: 0,
            mediaBox: mediaBox
        )
        let behindLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: behind,
            pageRotation: 0,
            mediaBox: mediaBox
        )

        XCTAssertEqual(aboveLayout, behindLayout)
    }

    func testBehindContentExportPreservesSearchableText() throws {
        let expectedText = "LayerBehindSearchable"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "behind-layer", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)

        var settings = enabledWatermark()
        settings.layer = .behindContent

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "behind-layer",
            watermarkSettings: settings
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testDocumentModeThumbnailReflectsBehindLayer() async throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "thumb-behind", text: "ThumbBehindSource")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)

        var settings = enabledWatermark()
        settings.layer = .behindContent

        let thumbnail = await ThumbnailService.shared.thumbnail(
            for: pages[0],
            document: imported.document,
            overlays: [],
            annotations: [],
            overlayImages: [:],
            revision: 0,
            watermarkSettings: settings
        )
        XCTAssertNotNil(thumbnail)
    }

    func testPageModePreviewReflectsBehindLayer() async throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "page-behind", text: "PageBehindSource")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)

        var settings = enabledWatermark()
        settings.layer = .behindContent

        let pageImage = await PageRenderService.shared.pageImage(
            for: pages[0],
            document: imported.document,
            watermarkSettings: settings
        )
        XCTAssertNotNil(pageImage)
    }

    @MainActor
    func testChangingWatermarkLayerIsUndoable() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        var settings = WatermarkSettings.default
        settings.text = "LAYER"
        settings.layer = .behindContent
        viewModel.applyWatermark(settings)
        XCTAssertEqual(viewModel.watermarkSettings.layer, .behindContent)

        viewModel.undo()
        XCTAssertEqual(viewModel.watermarkSettings, .default)
    }

    private func watermarkSettings(layer: WatermarkLayer) -> WatermarkSettings {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.text = "TEST"
        settings.opacity = 1
        settings.normalizedScale = 0.5
        settings.rotationDegrees = 0
        settings.position = .center
        settings.color = .red
        settings.layer = layer
        return settings
    }

    private func enabledWatermark() -> WatermarkSettings {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.text = "DRAFT"
        settings.opacity = 1
        settings.normalizedScale = 0.05
        settings.rotationDegrees = 0
        return settings
    }

    private func projectSourceURL(file: String, subdirectory: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(file)
    }
}
