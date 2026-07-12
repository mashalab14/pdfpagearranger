import XCTest
@testable import pdfpagearranger

final class ScanDraftProcessingCacheRegressionTests: XCTestCase {
    func testProcessingCacheReuseWhenSettingsDoNotChange() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let page = try XCTUnwrap(document.pages.first)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)

        let firstResult = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
        let firstFingerprint = try XCTUnwrap(firstResult.page.processingFingerprint)
        XCTAssertEqual(firstResult.page.processingState, .ready)
        XCTAssertNotNil(firstResult.page.processedImage)

        let secondResult = try await orchestrator.processPage(firstResult.page, sessionDirectory: sessionDirectory)
        XCTAssertEqual(secondResult.page.processingFingerprint, firstFingerprint)
        XCTAssertEqual(secondResult.page.processedImage, firstResult.page.processedImage)
        XCTAssertFalse(secondResult.page.needsProcessing)
    }

    func testProcessingCacheInvalidatesWhenVisualSettingsChange() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        var page = try XCTUnwrap(document.pages.first)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)

        let processed = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
        let originalFingerprint = try XCTUnwrap(processed.page.processingFingerprint)

        page = processed.page
        page.visualAdjustments.mode = .enhanced
        XCTAssertTrue(page.needsProcessing)
        XCTAssertNotEqual(ScanProcessingFingerprint.value(for: page), originalFingerprint)

        let reprocessed = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
        XCTAssertNotEqual(reprocessed.page.processingFingerprint, originalFingerprint)
        XCTAssertEqual(reprocessed.page.processingState, .ready)
    }

    func testProcessingCacheInvalidatesWhenGeometryChanges() async throws {
        var page = ScanDraftPage(
            sourceType: .camera,
            originalImage: ScanDraftImageReference(relativePath: "originals/a.jpg"),
            originalPixelSize: CGSize(width: 100, height: 100),
            geometry: .default,
            processingState: .ready,
            processingFingerprint: "cached"
        )

        page.geometry.rotation = 90
        XCTAssertTrue(page.needsProcessing)
    }

    func testFingerprintChangesWhenCropGeometryChanges() {
        var basePage = ScanDraftPage(
            sourceType: .photos,
            originalImage: ScanDraftImageReference(relativePath: "originals/shared.jpg"),
            originalPixelSize: CGSize(width: 200, height: 300),
            geometry: .default,
            visualAdjustments: .neutral
        )

        let baseFingerprint = ScanProcessingFingerprint.value(for: basePage)

        basePage.geometry.cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let updatedFingerprint = ScanProcessingFingerprint.value(for: basePage)

        XCTAssertNotEqual(baseFingerprint, updatedFingerprint)
    }
}
