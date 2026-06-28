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

    func testCompressionReducesFileSizeForImageHeavyPDF() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "ImageHeavy", pageCount: 1)
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "ImageHeavy"
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertFileSizeReduced(
            originalURL: sourceURL,
            compressedURL: result.outputURL,
            minimumReduction: 0.10
        )
        XCTAssertTrue(result.meaningfulCompression)
    }

    func testCompressionPreservesPageCount() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "ImageHeavyMulti", pageCount: 3)
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .smallestFile),
            outputName: "ImageHeavyMulti"
        )
        tempURLs.append(result.outputURL)

        try ExportAssertions.assertPageCount(3, in: result.outputURL)
    }

    func testCompressionPreservesPageOrder() async throws {
        let sourceURL = try PDFTestFactory.writePDF(
            named: "Ordered",
            pageCount: 3,
            labels: ["Alpha", "Beta", "Gamma"]
        )
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .highestQuality),
            outputName: "Ordered"
        )
        tempURLs.append(result.outputURL)

        let document = try XCTUnwrap(PDFDocument(url: result.outputURL))
        XCTAssertEqual(document.page(at: 0)?.string?.contains("Alpha"), true)
        XCTAssertEqual(document.page(at: 1)?.string?.contains("Beta"), true)
        XCTAssertEqual(document.page(at: 2)?.string?.contains("Gamma"), true)
    }

    func testCompressionPreservesPageRotations() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "RotatedImageHeavy", pageCount: 1)
        tempURLs.append(sourceURL)
        let document = try XCTUnwrap(PDFDocument(url: sourceURL))
        document.page(at: 0)?.rotation = 90

        let rotatedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RotatedImageHeavy-\(UUID().uuidString).pdf")
        tempURLs.append(rotatedURL)
        XCTAssertTrue(document.write(to: rotatedURL))

        let inputDocument = try XCTUnwrap(PDFDocument(url: rotatedURL))
        XCTAssertEqual(inputDocument.page(at: 0)?.rotation, 90)

        let result = try await compressionService.compress(
            inputURL: rotatedURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "RotatedImageHeavy"
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

        let exportedDocument = try XCTUnwrap(PDFDocument(url: exportURL))
        let strategy = ImageDownsampleCompressionStrategy()
        let compressedDocument = try strategy.compressDocument(
            exportedDocument,
            settings: CompressionSettings(preset: .highestQuality),
            progress: { _ in },
            isCancelled: { false }
        )

        let compressedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OverlayExport-compressed-\(UUID().uuidString).pdf")
        tempURLs.append(compressedURL)
        XCTAssertTrue(compressedDocument.write(to: compressedURL))

        try ExportAssertions.assertPageCount(1, in: compressedURL)
        try ExportAssertions.assertPageContainsText("OverlayExportText", at: 0, in: compressedURL)
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    func testCompressionPreservesSearchableTextWhenPossible() async throws {
        let expectedText = "SelectableCompressionText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "TextOnlyCompression", text: expectedText)
        tempURLs.append(sourceURL)

        let result = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "TextOnlyCompression"
        )
        tempURLs.append(result.outputURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: result.outputURL)
    }

    func testCompressionNeverModifiesOriginalPDF() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "OriginalGuard", pageCount: 1)
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

    func testCompressionReportsInsufficientSavingsForAlreadyOptimizedTextPDF() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "AlreadySmallImage", pageCount: 1)
        tempURLs.append(sourceURL)

        let firstPass = try await compressionService.compress(
            inputURL: sourceURL,
            settings: CompressionSettings(preset: .balanced),
            outputName: "AlreadySmallPass1"
        )
        tempURLs.append(firstPass.outputURL)

        do {
            _ = try await compressionService.compress(
                inputURL: firstPass.outputURL,
                settings: CompressionSettings(preset: .highestQuality),
                outputName: "AlreadySmallPass2"
            )
            XCTFail("Expected insufficient savings when recompressing an already optimized PDF")
        } catch let error as CompressionError {
            XCTAssertEqual(error, .insufficientSavings)
        }
    }

    func testExportSourceDoesNotUseRasterizedPageInitializerAfterCompressionWork() throws {
        try ExportAssertions.assertExportDoesNotUseRasterizedPageInitializer()
    }

    @MainActor
    func testCompressedPDFRendersThumbnail() async throws {
        let sourceURL = try PDFTestFactory.writeImageHeavyPDF(named: "ThumbSource", pageCount: 1)
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
            overlayImages: [:],
            revision: 0
        )
        XCTAssertNotNil(thumbnail)
    }
}

@MainActor
final class CompressionViewModelRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.writeImageHeavyPDF(named: "VMImageHeavy", pageCount: 1)
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

        let result = try await viewModel.compressPreparedPDF(
            prepared,
            settings: CompressionSettings(preset: .balanced)
        )
        tempURLs.append(result.outputURL)

        try CompressionAssertions.assertFileSizeReduced(
            originalURL: prepared.exportURL,
            compressedURL: result.outputURL
        )
    }
}
