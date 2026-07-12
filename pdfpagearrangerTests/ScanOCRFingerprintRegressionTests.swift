import XCTest
@testable import pdfpagearranger

final class ScanOCRFingerprintRegressionTests: XCTestCase {
    func testGeometryChangesInvalidateOCRFingerprint() {
        var page = ScanOCRTestFactory.makeProcessedPageWithFingerprint()
        let base = ScanOCRFingerprint.value(for: page, configuration: .default)
        page.ocrCache = ScanDraftOCRCacheEntry(
            relativePath: "ocr/\(page.id.uuidString).json",
            fingerprint: base,
            imagePixelSize: CGSize(width: 400, height: 600),
            status: .succeeded,
            errorMessage: nil
        )

        page.geometry.rotation = 90
        page.processingFingerprint = ScanProcessingFingerprint.value(for: page)
        let rotated = ScanOCRFingerprint.value(for: page, configuration: .default)

        XCTAssertNotEqual(base, rotated)
        XCTAssertFalse(ScanOCRFingerprint.isCacheValid(for: page, configuration: .default))
    }

    func testVisualAdjustmentChangesInvalidateOCRFingerprint() {
        var page = ScanOCRTestFactory.makeProcessedPageWithFingerprint()
        page.ocrCache = ScanDraftOCRCacheEntry(
            relativePath: "ocr/\(page.id.uuidString).json",
            fingerprint: ScanOCRFingerprint.value(for: page, configuration: .default),
            imagePixelSize: CGSize(width: 400, height: 600),
            status: .succeeded,
            errorMessage: nil
        )

        XCTAssertTrue(ScanOCRFingerprint.isCacheValid(for: page, configuration: .default))

        page.visualAdjustments.mode = .enhanced
        page.processingFingerprint = ScanProcessingFingerprint.value(for: page)
        XCTAssertFalse(ScanOCRFingerprint.isCacheValid(for: page, configuration: .default))
    }

    func testPageReorderDoesNotInvalidateOCRFingerprint() {
        let page = ScanOCRTestFactory.makeProcessedPageWithFingerprint()
        let fingerprint = ScanOCRFingerprint.value(for: page, configuration: .default)
        var cachedPage = page
        cachedPage.ocrCache = ScanDraftOCRCacheEntry(
            relativePath: "ocr/\(page.id.uuidString).json",
            fingerprint: fingerprint,
            imagePixelSize: CGSize(width: 400, height: 600),
            status: .succeeded,
            errorMessage: nil
        )

        XCTAssertTrue(ScanOCRFingerprint.isCacheValid(for: cachedPage, configuration: .default))
    }

    func testMatchingFingerprintReusesCachedOCR() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )

        let recognizer = FakeScanTextRecognizer()
        recognizer.configuredLines = [
            ScanOCRTestFactory.makeLine(text: "Cached text", box: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        ]
        let ocrService = ScanOCRService(storage: storage, recognizer: recognizer)

        let imageData = try storage.loadImageData(
            at: try XCTUnwrap(processed.page.processedImage),
            sessionDirectory: sessionDirectory
        )

        let first = try await ocrService.recognizePageIfNeeded(
            page: processed.page,
            processedImageData: imageData,
            sessionDirectory: sessionDirectory,
            configuration: .default
        )
        XCTAssertEqual(first.0.status, .succeeded)

        let second = try await ocrService.recognizePageIfNeeded(
            page: first.1,
            processedImageData: imageData,
            sessionDirectory: sessionDirectory,
            configuration: .default
        )

        XCTAssertEqual(recognizer.callCount, 1)
        XCTAssertEqual(second.0.lines.first?.text, "Cached text")
    }
}
