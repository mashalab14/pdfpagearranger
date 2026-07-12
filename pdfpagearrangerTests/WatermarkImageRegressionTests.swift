import CoreGraphics
import PDFKit
import UIKit
import XCTest
@testable import pdfpagearranger

final class WatermarkImageRegressionTests: XCTestCase {
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

    private func watermarkImage(
        color: UIColor = .blue,
        size: CGSize = CGSize(width: 200, height: 100)
    ) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func imageSettings(
        normalizedScale: CGFloat = 0.35,
        rotationDegrees: CGFloat = 45,
        opacity: CGFloat = 0.5,
        position: WatermarkPosition = .center,
        layer: WatermarkLayer = .aboveContent,
        scope: WatermarkApplyScope = .allPages
    ) -> WatermarkSettings {
        WatermarkSettings(
            isEnabled: true,
            watermarkType: .image,
            text: WatermarkSettings.default.text,
            imageAssetID: UUID(),
            opacity: opacity,
            normalizedScale: normalizedScale,
            color: .defaultGray,
            rotationDegrees: rotationDegrees,
            position: position,
            layer: layer,
            applyScope: scope,
            currentPageIndex: 1,
            rangeStart: 1,
            rangeEnd: 1
        )
    }

    func testImageSettingsStoreAssetReferenceNotBinaryData() throws {
        var settings = imageSettings()
        let assetID = UUID()
        settings.imageAssetID = assetID

        let data = try JSONEncoder().encode(settings)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains(assetID.uuidString))
        XCTAssertFalse(json.contains("base64"))
        XCTAssertEqual(settings.watermarkType, .image)
        XCTAssertTrue(settings.hasRenderableContent)
    }

    @MainActor
    func testImageImportFromUIImageStoresSessionAsset() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        let image = watermarkImage()
        viewModel.applyWatermark(imageSettings(), watermarkImage: image)

        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .image)
        XCTAssertNotNil(viewModel.watermarkSettings.imageAssetID)
        XCTAssertNotNil(viewModel.watermarkImage)
        XCTAssertEqual(viewModel.watermarkImage?.size, image.size)
    }

    func testImageContentSizePreservesAspectRatio() {
        let image = watermarkImage(size: CGSize(width: 400, height: 200))
        var settings = imageSettings(normalizedScale: 0.30)
        let renderWidth: CGFloat = 612

        let contentSize = WatermarkGeometryEngine.contentSize(
            settings: settings,
            renderWidth: renderWidth,
            image: image
        )

        XCTAssertNotNil(contentSize)
        guard let contentSize else { return }
        XCTAssertEqual(contentSize.width, renderWidth * settings.normalizedScale, accuracy: 0.01)
        XCTAssertEqual(contentSize.height / contentSize.width, 0.5, accuracy: 0.01)
    }

    func testImageNormalizedGeometryMatchesAcrossRenderTargets() {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let image = watermarkImage()
        var settings = imageSettings()

        let displaySize = OverlayGeometryEngine.displayRenderSize(
            for: 0,
            mediaBox: mediaBox
        )
        let thumbnailSize = CGSize(width: 120, height: 120 * displaySize.height / displaySize.width)
        let pageModeSize = CGSize(width: 1024, height: 1024 * displaySize.height / displaySize.width)

        let normalized = WatermarkGeometryEngine.normalizedLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: mediaBox,
            image: image
        )
        let thumbnail = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: mediaBox,
            renderSize: thumbnailSize,
            coordinateSpace: .topLeftOrigin,
            image: image
        )
        let pageMode = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: mediaBox,
            renderSize: pageModeSize,
            coordinateSpace: .topLeftOrigin,
            image: image
        )
        let export = WatermarkGeometryEngine.concreteLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: mediaBox,
            renderSize: displaySize,
            coordinateSpace: .pdfMediaBox,
            image: image
        )

        XCTAssertNotNil(normalized)
        XCTAssertNotNil(thumbnail)
        XCTAssertNotNil(pageMode)
        XCTAssertNotNil(export)

        guard let normalized, let thumbnail, let pageMode, let export else { return }

        func normalizedBounds(_ bounds: CGRect, renderSize: CGSize) -> CGRect {
            CGRect(
                x: bounds.minX / renderSize.width,
                y: bounds.minY / renderSize.height,
                width: bounds.width / renderSize.width,
                height: bounds.height / renderSize.height
            )
        }

        let tolerance: CGFloat = 0.02
        let thumbNorm = normalizedBounds(thumbnail.bounds, renderSize: thumbnailSize)
        let pageNorm = normalizedBounds(pageMode.bounds, renderSize: pageModeSize)
        XCTAssertEqual(thumbNorm.minX, pageNorm.minX, accuracy: tolerance)
        XCTAssertEqual(thumbNorm.width, pageNorm.width, accuracy: tolerance)
        XCTAssertEqual(thumbNorm.width, normalized.bounds.width, accuracy: tolerance)
        XCTAssertEqual(export.rotationDegrees, normalized.rotationDegrees)
    }

    func testMixedPageSizesUseSameNormalizedImageScale() {
        let image = watermarkImage()
        let settings = imageSettings(normalizedScale: 0.30)
        let letterBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let a4Box = CGRect(x: 0, y: 0, width: 595, height: 842)

        let letterLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: letterBox,
            image: image
        )
        let a4Layout = WatermarkGeometryEngine.normalizedLayout(
            settings: settings,
            pageRotation: 0,
            mediaBox: a4Box,
            image: image
        )

        XCTAssertEqual(letterLayout?.scale, a4Layout?.scale)
        XCTAssertEqual(letterLayout?.bounds.width ?? 0, a4Layout?.bounds.width ?? 0, accuracy: 0.02)
    }

    func testRotatedPageImageWatermarkGeometry() {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let image = watermarkImage()
        let settings = imageSettings(rotationDegrees: 90, position: .bottom)

        XCTAssertNotNil(
            WatermarkGeometryEngine.normalizedLayout(
                settings: settings,
                pageRotation: 90,
                mediaBox: mediaBox,
                image: image
            )
        )
    }

    func testImageWatermarkExportPreservesSearchableOriginalText() throws {
        let expectedText = "SearchableSource"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "image-watermark-searchable", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let image = watermarkImage()
        let settings = imageSettings(normalizedScale: 0.20, opacity: 1)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "image-watermark-searchable",
            watermarkSettings: settings,
            watermarkImage: image
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
    }

    func testImageWatermarkAboveContentExport() throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "image-above", text: "AboveContent")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        var settings = imageSettings(layer: .aboveContent)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "image-above",
            watermarkSettings: settings,
            watermarkImage: watermarkImage()
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("AboveContent", at: 0, in: exportURL)
        XCTAssertGreaterThan(try Data(contentsOf: exportURL).count, 500)
    }

    func testImageWatermarkBehindContentExport() throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "image-behind", text: "BehindContent")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        var settings = imageSettings(layer: .behindContent)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "image-behind",
            watermarkSettings: settings,
            watermarkImage: watermarkImage()
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("BehindContent", at: 0, in: exportURL)
    }

    func testPreviewAndExportBothIncludeImageWatermark() async throws {
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "image-preview-parity", text: "PreviewParity")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)
        let image = watermarkImage(color: .red, size: CGSize(width: 80, height: 40))
        let settings = imageSettings(normalizedScale: 0.25, opacity: 0.8)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "image-preview-parity",
            watermarkSettings: settings,
            watermarkImage: image
        )
        tempURLs.append(exportURL)

        let thumbnail = await ThumbnailService.shared.thumbnail(
            for: pages[0],
            document: imported.document,
            overlays: [],
            annotations: [],
            overlayImages: [:],
            revision: 0,
            watermarkSettings: settings,
            watermarkImage: image
        )
        let pageImage = await PageRenderService.shared.pageImage(
            for: pages[0],
            document: imported.document,
            watermarkSettings: settings,
            watermarkImage: image
        )

        XCTAssertNotNil(thumbnail)
        XCTAssertNotNil(pageImage)
    }

    func testMixedPageSizesImageWatermarkExport() throws {
        let sourceURL = try PDFTestFactory.writeMixedPageSizesPDF(named: "image-mixed")
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        let pages = pdfService.makeInitialPages(pageCount: 2)
        let image = watermarkImage()

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "image-mixed",
            watermarkSettings: imageSettings(),
            watermarkImage: image
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageCount(2, in: exportURL)
        try ExportAssertions.assertPageContainsText("LetterPage", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("A4Page", at: 1, in: exportURL)
    }

    @MainActor
    func testSwitchingBetweenTextAndImageWatermarkIsUndoable() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        var textSettings = WatermarkSettings.default
        textSettings.text = "TEXT"
        viewModel.applyWatermark(textSettings)
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .text)

        viewModel.applyWatermark(imageSettings(), watermarkImage: watermarkImage())
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .image)
        XCTAssertNotNil(viewModel.watermarkImage)

        viewModel.undo()
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .text)
        XCTAssertEqual(viewModel.watermarkSettings.text, "TEXT")
        XCTAssertNil(viewModel.watermarkSettings.imageAssetID)

        viewModel.undo()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)
    }

    @MainActor
    func testRemoveImageWatermarkClearsAssetAndSettings() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        viewModel.applyWatermark(imageSettings(), watermarkImage: watermarkImage())
        XCTAssertNotNil(viewModel.watermarkImage)

        viewModel.removeWatermark()
        XCTAssertFalse(viewModel.watermarkSettings.isEnabled)
        XCTAssertEqual(viewModel.watermarkSettings, .default)
        XCTAssertNil(viewModel.watermarkImage)
    }

    @MainActor
    func testChangingImageWatermarkReplacesSessionAsset() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        viewModel.applyWatermark(imageSettings(), watermarkImage: watermarkImage(color: .red))
        let firstAssetID = try XCTUnwrap(viewModel.watermarkSettings.imageAssetID)

        viewModel.applyWatermark(imageSettings(), watermarkImage: watermarkImage(color: .green))
        let secondAssetID = try XCTUnwrap(viewModel.watermarkSettings.imageAssetID)

        XCTAssertNotEqual(firstAssetID, secondAssetID)
        XCTAssertNotNil(viewModel.watermarkImage)
    }

    func testWatermarkRendererUsesImageDrawPathForImageContent() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("case .image:"))
        XCTAssertTrue(source.contains("OverlayGeometryEngine.drawPDFImage"))
        XCTAssertTrue(source.contains("OverlayGeometryEngine.drawUIImage"))
    }

    func testPhotosAndFilesImportPathsExistInWatermarkView() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkView.swift", subdirectory: "Views"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("PhotosPicker"))
        XCTAssertTrue(source.contains("fileImporter"))
        XCTAssertTrue(source.contains("watermarkTypePicker"))
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
