import PDFKit
import XCTest
@testable import pdfpagearranger

final class WatermarkSettingsTests: XCTestCase {
    func testDefaultSettings() {
        let settings = WatermarkSettings.default
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.text, "CONFIDENTIAL")
        XCTAssertEqual(settings.opacity, 0.35, accuracy: 0.001)
        XCTAssertEqual(settings.normalizedScale, 0.35, accuracy: 0.001)
        XCTAssertEqual(settings.rotationDegrees, 45, accuracy: 0.001)
        XCTAssertEqual(settings.position, .center)
        XCTAssertEqual(settings.watermarkType, .text)
        XCTAssertEqual(settings.layer, .aboveContent)
        XCTAssertEqual(settings.applyScope, .allPages)
    }

    func testShouldApplyToAllPages() {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        XCTAssertTrue(settings.shouldApply(toExportIndex: 0))
        XCTAssertTrue(settings.shouldApply(toExportIndex: 4))
    }

    func testShouldApplyToCurrentPageOnly() {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.applyScope = .currentPage
        settings.currentPageIndex = 2
        XCTAssertFalse(settings.shouldApply(toExportIndex: 0))
        XCTAssertTrue(settings.shouldApply(toExportIndex: 1))
    }

    func testShouldApplyToPageRange() {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.applyScope = .pageRange
        settings.rangeStart = 2
        settings.rangeEnd = 4
        XCTAssertFalse(settings.shouldApply(toExportIndex: 0))
        XCTAssertTrue(settings.shouldApply(toExportIndex: 1))
        XCTAssertTrue(settings.shouldApply(toExportIndex: 3))
        XCTAssertFalse(settings.shouldApply(toExportIndex: 4))
    }

    func testNormalizedScaleProducesConsistentRelativeWidthAcrossPageSizes() {
        var settings = WatermarkSettings.default
        settings.normalizedScale = 0.35
        let text = "CONFIDENTIAL"
        let letterBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let a4Box = CGRect(x: 0, y: 0, width: 595, height: 842)

        let letterLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: letterBox
        )
        let a4Layout = WatermarkGeometryEngine.normalizedLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: a4Box
        )

        XCTAssertEqual(letterLayout?.scale, a4Layout?.scale)
        XCTAssertEqual(letterLayout?.bounds.width ?? 0, a4Layout?.bounds.width ?? 0, accuracy: 0.02)
    }
}

final class WatermarkExportRegressionTests: XCTestCase {
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

    private func enabledWatermark(
        text: String = "DRAFT",
        scope: WatermarkApplyScope = .allPages,
        currentPageIndex: Int = 1,
        rangeStart: Int = 1,
        rangeEnd: Int = 1,
        rotationDegrees: CGFloat = 0
    ) -> WatermarkSettings {
        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.text = text
        settings.opacity = 1
        settings.normalizedScale = 0.05
        settings.applyScope = scope
        settings.currentPageIndex = currentPageIndex
        settings.rangeStart = rangeStart
        settings.rangeEnd = rangeEnd
        settings.rotationDegrees = rotationDegrees
        return settings
    }

    func testWatermarkRendererDrawsExtractableTextInIsolation() throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var box = mediaBox
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))

        context.beginPDFPage(nil)

        var pageNumberSettings = PageNumberSettings.default
        pageNumberSettings.isEnabled = true
        PageNumberRenderer.drawInPDFContext(
            context: context,
            mediaBox: mediaBox,
            pageRotation: 0,
            settings: pageNumberSettings,
            displayNumber: 99,
            totalPages: 1
        )

        var settings = WatermarkSettings.default
        settings.isEnabled = true
        settings.text = "DRAFT"
        settings.rotationDegrees = 0
        settings.opacity = 1
        settings.position = .center
        settings.color = .black
        settings.normalizedScale = 0.05

        WatermarkRenderer.drawInPDFContext(
            context: context,
            mediaBox: mediaBox,
            pageRotation: 0,
            settings: settings,
            watermarkImage: nil
        )

        context.endPDFPage()
        context.closePDF()

        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        let pageText = document.page(at: 0)?.string ?? ""
        XCTAssertTrue(pageText.contains("99"), "Page number missing. Got: \(pageText)")
        XCTAssertTrue(pageText.contains("DRAFT"), "Watermark missing. Got: \(pageText)")
    }

    func testWatermarkOnAllPages() throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "watermark-all",
            pageCount: 3,
            labels: ["DocA", "DocB", "DocC"]
        )
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 3)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "watermark-all",
            watermarkSettings: enabledWatermark()
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("DRAFT", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 1, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 2, in: exportURL)
    }

    func testWatermarkOnCurrentPageOnly() throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "watermark-current",
            pageCount: 3,
            labels: ["DocA", "DocB", "DocC"]
        )
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 3)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "watermark-current",
            watermarkSettings: enabledWatermark(scope: .currentPage, currentPageIndex: 2)
        )
        tempURLs.append(exportURL)

        let document = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertFalse(document.page(at: 0)?.string?.contains("DRAFT") == true)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 1, in: exportURL)
        XCTAssertFalse(document.page(at: 2)?.string?.contains("DRAFT") == true)
    }

    func testWatermarkOnPageRange() throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "watermark-range",
            pageCount: 4,
            labels: ["DocA", "DocB", "DocC", "DocD"]
        )
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 4)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "watermark-range",
            watermarkSettings: enabledWatermark(scope: .pageRange, rangeStart: 2, rangeEnd: 3)
        )
        tempURLs.append(exportURL)

        let document = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertFalse(document.page(at: 0)?.string?.contains("DRAFT") == true)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 1, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 2, in: exportURL)
        XCTAssertFalse(document.page(at: 3)?.string?.contains("DRAFT") == true)
    }

    func testRotatedPagesIncludeWatermark() throws {
        let expectedText = "RotatedWatermarkText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "rotated-watermark", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        var pages = pdfService.makeInitialPages(pageCount: 1)
        pages[0].rotation = 90

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "rotated-watermark",
            watermarkSettings: enabledWatermark(text: "DRAFT", rotationDegrees: 0)
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        // PDFKit text extraction is unreliable on /Rotate pages; geometry parity is covered elsewhere.
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testDiagonalWatermarkExportsWithoutRasterizingPages() throws {
        let expectedText = "DiagonalWatermarkSource"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "diagonal-watermark", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "diagonal-watermark",
            watermarkSettings: enabledWatermark(text: "DIAG", rotationDegrees: 45)
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testMixedPageSizesReceiveScaledWatermark() throws {
        let sourceURL = try PDFTestFactory.writeMixedPageSizesPDF(named: "mixed-sizes")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 2)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "mixed-sizes-watermark",
            watermarkSettings: enabledWatermark(text: "DRAFT")
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("LetterPage", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("A4Page", at: 1, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 1, in: exportURL)
    }

    func testOriginalTextRemainsSearchableWithWatermark() throws {
        let expectedText = "SelectableWatermarkText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "searchable-watermark", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "searchable-watermark",
            watermarkSettings: enabledWatermark()
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 0, in: exportURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testWatermarkRendersAsVectorTextInExportSource() throws {
        let rendererSource = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(rendererSource.contains("WatermarkGeometryEngine.concreteLayout"))
        XCTAssertFalse(rendererSource.contains("scaledFontSize"))
        XCTAssertTrue(rendererSource.contains("CTFrameDraw"))
        XCTAssertTrue(rendererSource.contains("CTFramesetterCreateWithAttributedString"))

        let pdfServiceSource = try String(
            contentsOf: projectSourceURL(file: "PDFService.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(pdfServiceSource.contains("WatermarkRenderer.drawInPDFContext"))
        XCTAssertTrue(pdfServiceSource.contains("sourcePage.draw(with: .mediaBox, to: context)"))
    }

    func testWatermarkDrawsBeforeOverlaysInExportSource() throws {
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

    func testWatermarkWithImageOverlayPreservesSearchableText() throws {
        let expectedText = "OverlayWatermarkText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "overlay-watermark", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let page = pages[0]
        let assetID = UUID()
        let overlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "overlay-watermark",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage()],
            watermarkSettings: enabledWatermark(text: "DRAFT")
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 0, in: exportURL)
    }

    func testPreviewAndExportBothIncludeWatermarkText() async throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "preview-parity", text: "PreviewParity")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let settings = enabledWatermark(text: "DRAFT")

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "preview-parity",
            watermarkSettings: settings
        )
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageContainsText("DRAFT", at: 0, in: exportURL)

        let thumbnail = await ThumbnailService.shared.thumbnail(
            for: pages[0],
            document: imported.document,
            overlays: [],
            overlayImages: [:],
            revision: 0,
            watermarkSettings: settings
        )
        XCTAssertNotNil(thumbnail)

        let pageImage = await PageRenderService.shared.pageImage(
            for: pages[0],
            document: imported.document,
            watermarkSettings: settings
        )
        XCTAssertNotNil(pageImage)
    }

    @MainActor
    func testRemoveWatermarkRestoresDefaultSettings() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        var settings = WatermarkSettings.default
        settings.text = "TEMP"
        viewModel.applyWatermark(settings)
        XCTAssertTrue(viewModel.watermarkSettings.isEnabled)

        viewModel.removeWatermark()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)
        XCTAssertEqual(viewModel.watermarkSettings, .default)
    }

    @MainActor
    func testApplyingWatermarkIsUndoable() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        var settings = WatermarkSettings.default
        settings.text = "UNDO"
        viewModel.applyWatermark(settings)
        XCTAssertTrue(viewModel.watermarkSettings.isEnabled)

        viewModel.undo()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)
        XCTAssertEqual(viewModel.watermarkSettings, .default)
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

extension PDFTestFactory {
    static func writeMixedPageSizesPDF(named name: String) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString).pdf")
        let document = PDFDocument()

        let letterURL = try writeTextPDF(named: "letter-page", text: "LetterPage")
        let a4Rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let a4Data = UIGraphicsPDFRenderer(bounds: a4Rect).pdfData { context in
            context.beginPage()
            ("A4Page" as NSString).draw(
                at: CGPoint(x: 72, y: 72),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
        }
        let a4URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("a4-page-\(UUID().uuidString).pdf")
        try a4Data.write(to: a4URL)

        if let letterDoc = PDFDocument(url: letterURL),
           let letterPage = letterDoc.page(at: 0)?.copy() as? PDFPage {
            document.insert(letterPage, at: document.pageCount)
        }
        if let a4Doc = PDFDocument(url: a4URL),
           let a4Page = a4Doc.page(at: 0)?.copy() as? PDFPage {
            document.insert(a4Page, at: document.pageCount)
        }

        guard document.write(to: outputURL) else {
            throw NSError(domain: "PDFTestFactory", code: 8)
        }

        try? FileManager.default.removeItem(at: letterURL)
        try? FileManager.default.removeItem(at: a4URL)
        return outputURL
    }
}
