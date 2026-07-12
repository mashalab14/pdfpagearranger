import PDFKit
import UIKit
import XCTest
@testable import pdfpagearranger

final class ScanDraftSearchablePDFRegressionTests: XCTestCase {
    func testSearchablePDFContainsSelectableText() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )

        let recognizer = FakeScanTextRecognizer()
        recognizer.configuredLines = [
            ScanOCRTestFactory.makeLine(
                text: "SearchableScanText",
                box: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.05)
            )
        ]

        let generator = ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator,
            ocrService: ScanOCRService(storage: storage, recognizer: recognizer)
        )

        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "Searchable",
            options: ScanDraftPDFGenerationOptions(makeSearchable: true, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        try ExportAssertions.assertPageContainsText("SearchableScanText", at: 0, in: result.url)
        XCTAssertTrue(result.nonSearchablePageIDs.isEmpty)
    }

    func testImageOnlyModeContainsNoOCRTextLayer() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )

        let recognizer = FakeScanTextRecognizer()
        recognizer.configuredLines = [
            ScanOCRTestFactory.makeLine(text: "HiddenWhenDisabled", box: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05))
        ]

        let generator = ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator,
            ocrService: ScanOCRService(storage: storage, recognizer: recognizer)
        )

        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "ImageOnly",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        let pdfDocument = try XCTUnwrap(PDFDocument(url: result.url))
        let pageText = pdfDocument.page(at: 0)?.string ?? ""
        XCTAssertTrue(pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(recognizer.callCount, 0)
    }

    func testMixedOCRSuccessAndFailurePagesStillGenerateValidPDF() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 2, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        var processedPages: [ScanDraftPage] = []
        for page in document.pages {
            processedPages.append(try await orchestrator.processPage(page, sessionDirectory: sessionDirectory).page)
        }

        let recognizer = FailingOnSecondCallScanTextRecognizer()

        let generator = ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator,
            ocrService: ScanOCRService(storage: storage, recognizer: recognizer)
        )

        let result = try await generator.generatePDF(
            from: processedPages,
            sessionDirectory: sessionDirectory,
            displayName: "Mixed OCR",
            options: ScanDraftPDFGenerationOptions(makeSearchable: true, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        let pdfDocument = try XCTUnwrap(PDFDocument(url: result.url))
        XCTAssertEqual(pdfDocument.pageCount, 2)
        XCTAssertEqual(result.nonSearchablePageIDs.count, 1)
        try ExportAssertions.assertPageContainsText("SuccessfulPageText", at: 0, in: result.url)
    }

    func testOnePageOCRFailureFallsBackToImageOnlyForThatPage() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )

        let recognizer = FakeScanTextRecognizer()
        recognizer.shouldThrow = true

        let generator = ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator,
            ocrService: ScanOCRService(storage: storage, recognizer: recognizer)
        )

        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "OCR Failure",
            options: ScanDraftPDFGenerationOptions(makeSearchable: true, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        XCTAssertEqual(PDFDocument(url: result.url)?.pageCount, 1)
        XCTAssertEqual(result.nonSearchablePageIDs.count, 1)
    }

    func testCancellationRemovesPartialOutput() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )

        let recognizer = SlowFakeScanTextRecognizer()
        let generator = ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator,
            ocrService: ScanOCRService(storage: storage, recognizer: recognizer)
        )

        let task = Task {
            try await generator.generatePDF(
                from: [processed.page],
                sessionDirectory: sessionDirectory,
                displayName: "Cancel",
                options: ScanDraftPDFGenerationOptions(makeSearchable: true, ocrConfiguration: .default),
                onProgress: nil,
                onPagePrepared: nil
            )
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let generatedDirectory = sessionDirectory.appendingPathComponent("generated", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: generatedDirectory, includingPropertiesForKeys: nil)
        XCTAssertTrue(contents.filter { $0.lastPathComponent.hasSuffix(".staging.pdf") }.isEmpty)
        XCTAssertTrue(contents.filter { $0.lastPathComponent.hasSuffix(".pdf") }.isEmpty)
    }

    func testExtractedTextFollowsReadingOrder() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )

        let recognizer = FakeScanTextRecognizer()
        recognizer.configuredLines = [
            ScanOCRTestFactory.makeLine(text: "Alpha", box: CGRect(x: 0.05, y: 0.8, width: 0.35, height: 0.04)),
            ScanOCRTestFactory.makeLine(text: "Beta", box: CGRect(x: 0.55, y: 0.78, width: 0.35, height: 0.04)),
            ScanOCRTestFactory.makeLine(text: "Gamma", box: CGRect(x: 0.05, y: 0.5, width: 0.35, height: 0.04))
        ]

        let generator = ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator,
            ocrService: ScanOCRService(storage: storage, recognizer: recognizer)
        )

        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "Reading Order",
            options: ScanDraftPDFGenerationOptions(makeSearchable: true, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        let pageText = try XCTUnwrap(PDFDocument(url: result.url)?.page(at: 0)?.string)
        let alphaRange = try XCTUnwrap(pageText.range(of: "Alpha"))
        let betaRange = try XCTUnwrap(pageText.range(of: "Beta"))
        let gammaRange = try XCTUnwrap(pageText.range(of: "Gamma"))
        XCTAssertTrue(alphaRange.lowerBound < betaRange.lowerBound)
        XCTAssertTrue(gammaRange.lowerBound < betaRange.lowerBound)
    }
}

private final class FailingOnSecondCallScanTextRecognizer: ScanTextRecognizing, @unchecked Sendable {
    private var callCount = 0

    func recognizeLines(
        in imageData: Data,
        configuration: ScanOCRConfiguration
    ) async throws -> [OCRLine] {
        _ = imageData
        _ = configuration
        callCount += 1
        if callCount == 2 {
            throw ScanOCRRecognitionError.requestFailed
        }
        return [
            ScanOCRTestFactory.makeLine(
                text: "SuccessfulPageText",
                box: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.05)
            )
        ]
    }
}

private final class SlowFakeScanTextRecognizer: ScanTextRecognizing, @unchecked Sendable {
    func recognizeLines(
        in imageData: Data,
        configuration: ScanOCRConfiguration
    ) async throws -> [OCRLine] {
        _ = imageData
        _ = configuration
        try await Task.sleep(nanoseconds: 500_000_000)
        try Task.checkCancellation()
        return []
    }
}
