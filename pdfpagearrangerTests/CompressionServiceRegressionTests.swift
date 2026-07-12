import PDFKit
import XCTest
@testable import pdfpagearranger

final class CompressionServiceRegressionTests: XCTestCase {
    private var tempURLs: [URL] = []
    private let compressionService = CompressionService()

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        try await super.tearDown()
    }

    func testCompressionReducesFileSizeForMetadataHeavyPDF() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "MetadataHeavy",
            text: "MetadataHeavyCompressionText"
        )
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "MetadataHeavy"
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertFileSizeReduced(
            originalURL: sourceURL,
            compressedURL: result.outputURL,
            minimumReduction: 0.10
        )
        XCTAssertTrue(result.meaningfulCompression)
    }

    func testCompressionPreservesIdenticalPDFKitStringExtraction() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "StringExtraction",
            text: "IdenticalPDFKitStringExtractionText"
        )
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .smallestFile),
            outputName: "StringExtraction"
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertIdenticalPDFKitStringExtraction(
            sourceURL: sourceURL,
            compressedURL: result.outputURL
        )
    }

    func testCompressionDoesNotRasterizeTextOnlyPDFs() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "TextOnlyNoRaster",
            text: "TextOnlyPDFMustRemainVectorAndSearchable"
        )
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "TextOnlyNoRaster"
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertTextOnlyPDFWasNotRasterized(
            sourceURL: sourceURL,
            compressedURL: result.outputURL
        )
    }

    func testCompressionPreservesPageCount() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "MetadataHeavyMulti",
            text: "PageCountMetadataHeavy"
        )
        tempURLs.append(sourceURL)

        let multiPageURL = try writeMultiPageCopy(from: sourceURL, pageCount: 3)
        tempURLs.append(multiPageURL)

        let result = try await compressionService.compress(
            inputURL: multiPageURL,
            settings: CompressionSettings(preset: .smallestFile),
            outputName: "MetadataHeavyMulti"
        )
        tempURLs.append(result.outputURL)

        try ExportAssertions.assertPageCount(3, in: result.outputURL)
    }

    func testCompressionPreservesPageOrder() async throws {
        let baseURL = try PDFTestFactory.writePDF(
            named: "Ordered",
            pageCount: 3,
            labels: ["Alpha", "Beta", "Gamma"]
        )
        tempURLs.append(baseURL)

        let sourceURL = try PDFTestFactory.attachCompressionMetadata(to: baseURL, named: "OrderedWithMetadata")
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "Ordered"
        )
        tempURLs.append(result.outputURL)

        let document = try XCTUnwrap(PDFDocument(url: result.outputURL))
        XCTAssertEqual(document.page(at: 0)?.string?.contains("Alpha"), true)
        XCTAssertEqual(document.page(at: 1)?.string?.contains("Beta"), true)
        XCTAssertEqual(document.page(at: 2)?.string?.contains("Gamma"), true)
    }

    func testCompressionPreservesPageRotations() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "RotatedMetadataHeavy",
            text: "RotationShouldPersistInCompressionOutput"
        )
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        document.page(at: 0)?.rotation = 90

        let rotatedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RotatedMetadataHeavy-\(UUID().uuidString).pdf")
        tempURLs.append(rotatedURL)
        XCTAssertTrue(document.write(to: rotatedURL))

        let inputDocument = try XCTUnwrap(PDFDocument(url: rotatedURL))
        XCTAssertEqual(inputDocument.page(at: 0)?.rotation, 90)

        let result = try await compressionService.compress(
            inputURL: rotatedURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "RotatedMetadataHeavy"
        )
        tempURLs.append(result.outputURL)

        let compressed = try XCTUnwrap(PDFDocument(url: result.outputURL))
        XCTAssertEqual(compressed.page(at: 0)?.rotation, 90)
    }

    @MainActor
    func testCompressionPreservesExportedOverlaysAndSignatures() async throws {
        let viewModel = PDFEditorViewModel()
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "OverlayBase", text: "OverlayExportText")
        tempURLs.append(sourceURL)
        await viewModel.importPDF(from: sourceURL)

        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(color: .green, size: CGSize(width: 80, height: 80)),
            pageAspectRatio: 612.0 / 792.0
        )
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.blue.uiColor)
        let signatureImage = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        viewModel.addSignatureOverlay(
            to: page.id,
            image: signatureImage,
            pageAspectRatio: 612.0 / 792.0
        )

        let exportURL = try viewModel.exportPDF()
        tempURLs.append(exportURL)
        let metadataExportURL = try PDFTestFactory.attachCompressionMetadata(to: exportURL, named: "OverlayExport")
        tempURLs.append(metadataExportURL)

        let result = try await compressionService.compress(
            inputURL: metadataExportURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "OverlayExport"
        )
        tempURLs.append(result.outputURL)

        try ExportAssertions.assertPageCount(1, in: result.outputURL)
        try ExportAssertions.assertPageContainsText("OverlayExportText", at: 0, in: result.outputURL)
        try CompressionAssertions.assertIdenticalPDFKitStringExtraction(
            sourceURL: metadataExportURL,
            compressedURL: result.outputURL
        )
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testCompressionPreservesSearchableTextWhenPossible() async throws {
        let expectedText = "SelectableCompressionText"
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "TextOnlyCompression",
            text: expectedText
        )
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "TextOnlyCompression"
        )
        tempURLs.append(result.outputURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: result.outputURL)
        try CompressionAssertions.assertIdenticalPDFKitStringExtraction(
            sourceURL: sourceURL,
            compressedURL: result.outputURL
        )
    }

    func testCompressionNeverModifiesOriginalPDF() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "OriginalGuard",
            text: "OriginalGuardText"
        )
        tempURLs.append(sourceURL)
        let originalData = try Data(contentsOf: sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "OriginalGuard"
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertOriginalPDFUnchanged(
            originalData: originalData,
            currentURL: sourceURL
        )
        XCTAssertNotEqual(
            try Data(contentsOf: sourceURL),
            try Data(contentsOf: result.outputURL)
        )
    }

    @MainActor
    func testCompressionNeverModifiesImportedPDFByteForByte() async throws {
        let viewModel = PDFEditorViewModel()
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "ImportedOriginalGuard",
            text: "ImportedOriginalGuardText"
        )
        tempURLs.append(sourceURL)

        await viewModel.importPDF(from: sourceURL)
        let importedURL = try XCTUnwrap(viewModel.localSourceURL)
        let importedData = try Data(contentsOf: importedURL)

        let prepared = try await viewModel.prepareCompressionInput()
        tempURLs.append(prepared.exportURL)
        let metadataExportURL = try PDFTestFactory.attachCompressionMetadata(
            to: prepared.exportURL,
            named: "ImportedCompressionExport"
        )
        tempURLs.append(metadataExportURL)

        let result = try await viewModel.compressPreparedPDF(
            CompressionPreparedInput(
                exportURL: metadataExportURL,
                byteCount: prepared.byteCount
            ),
            settings: CompressionSettings(preset: .balanced)
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertOriginalPDFUnchanged(
            originalData: importedData,
            currentURL: importedURL
        )
    }

    func testCompressionFailureReturnsProperErrorForMissingFile() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).pdf")

        do {
            _ = try await compressionService.compress(
                inputURL: missingURL,
                settings: CompressionSettings(preset: .balanced),
                outputName: "Missing"
            )
            XCTFail("Expected compression to fail for missing input")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .unreadableInput)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCompressionReportsInsufficientSavingsForAlreadyOptimizedPDF() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "AlreadyOptimized",
            text: "AlreadyOptimizedText"
        )
        tempURLs.append(sourceURL)

        let firstPass = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .smallestFile),
            outputName: "AlreadyOptimizedPass1"
        )
        tempURLs.append(firstPass.outputURL)

        do {
            _ = try await compressionService.compress(
                inputURL: firstPass.outputURL,
                settings: CompressionSettings(preset: .highestQuality),
                outputName: "AlreadyOptimizedPass2"
            )
            XCTFail("Expected insufficient savings when recompressing an already optimized PDF")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .insufficientSavings)
        }
    }

    func testCompressionReportsInsufficientSavingsForImageHeavyPDFWithoutRasterization() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "ImageHeavyNoRaster", pageCount: 1)
        tempURLs.append(sourceURL)

        do {
            _ = try await compressionService.compress(
                inputURL: sourceURL,
                settings: CompressionSettings(preset: .balanced),
                outputName: "ImageHeavyNoRaster"
            )
            XCTFail("Expected insufficient savings for image-heavy PDF without page rasterization")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .insufficientSavings)
        }
    }

    func testExportSourceDoesNotUseRasterizedPageInitializerAfterCompressionWork() throws {
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testCompressedPDFRendersThumbnail() async throws {
        let sourceURL = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "ThumbSource",
            text: "ThumbnailCompressionText"
        )
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "ThumbSource"
        )
        tempURLs.append(result.outputURL)

        let document = try XCTUnwrap(PDFDocument(url: result.outputURL))
        let pageItem = PageItem(originalPageIndex: 0)
        let thumbnail = await ThumbnailService.shared.thumbnail(
            for: pageItem,
            document: document,
            overlays: [],
            annotations: [],
            overlayImages: [:],
            revision: 0
        )
        XCTAssertNotNil(thumbnail)
    }

    private func writeMultiPageCopy(from sourceURL: URL, pageCount: Int) throws -> URL {
        guard let sourceDocument = PDFDocument(url: sourceURL),
              let sourcePage = sourceDocument.page(at: 0)?.copy() as? PDFPage else {
            throw NSError(domain: "CompressionServiceRegressionTests", code: 1)
        }

        let document = PDFDocument()
        for _ in 0..<pageCount {
            guard let page = sourcePage.copy() as? PDFPage else { continue }
            document.insert(page, at: document.pageCount)
        }
        document.documentAttributes = sourceDocument.documentAttributes

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MultiPageMetadataHeavy-\(UUID().uuidString).pdf")
        guard document.write(to: outputURL) else {
            throw NSError(domain: "CompressionServiceRegressionTests", code: 2)
        }
        return outputURL
    }
}

@MainActor
final class CompressionViewModelRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.writeMetadataHeavyTextPDF(
            named: "VMMetadataHeavy",
            text: "ViewModelCompressionText"
        )
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

    func testPrepareAndCompressThroughViewModel() async throws {
        let prepared = try await viewModel.prepareCompressionInput()
        tempURLs.append(prepared.exportURL)

        let metadataExportURL = try PDFTestFactory.attachCompressionMetadata(to: prepared.exportURL, named: "VMExport")
        tempURLs.append(metadataExportURL)
        let metadataPrepared = CompressionPreparedInput(
            exportURL: metadataExportURL,
            byteCount: prepared.byteCount
        )

        let result = try await viewModel.compressPreparedPDF(
            metadataPrepared,
            settings: CompressionSettings(preset: .balanced)
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertFileSizeReduced(
            originalURL: metadataExportURL,
            compressedURL: result.outputURL
        )
        try CompressionAssertions.assertIdenticalPDFKitStringExtraction(
            sourceURL: metadataExportURL,
            compressedURL: result.outputURL
        )
    }
}
