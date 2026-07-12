import XCTest
@testable import pdfpagearranger

final class ScanDraftPageGeometryProcessorRegressionTests: XCTestCase {
    func testApplyGeometryPersistsProcessedOutputAndUpdatesFingerprint() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let processor = ScanDraftPageGeometryProcessor(storage: storage)
        let documentID = UUID()
        let sessionDirectory = try storage.createSessionDirectory(for: documentID)
        let pageID = UUID()

        var page = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(size: CGSize(width: 400, height: 600)),
            pageID: pageID,
            sourceType: .photos,
            sessionDirectory: sessionDirectory
        )

        var geometry = ScanPageGeometryEngine.initialGeometry(for: page)
        geometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners(inset: 0.05)
        geometry.perspectiveCorrectionEnabled = true

        let updated = try await processor.applyGeometry(
            to: page,
            geometry: geometry,
            sessionDirectory: sessionDirectory
        )

        XCTAssertEqual(updated.sourceType, .photos)
        XCTAssertNotNil(updated.processedImage)
        XCTAssertEqual(updated.processingState, .ready)
        XCTAssertNotNil(updated.processingFingerprint)
        XCTAssertEqual(updated.thumbnailState, .ready)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: updated.processedImage!.url(in: sessionDirectory).path
            )
        )
    }

    func testInvalidGeometryIsRejectedWithoutWritingProcessedOutput() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let processor = ScanDraftPageGeometryProcessor(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let page = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: UUID(),
            sourceType: .photos,
            sessionDirectory: sessionDirectory
        )

        var geometry = ScanPageGeometry.default
        geometry.userAdjustedCorners = [
            ScanNormalizedPoint(x: 0.1, y: 0.1),
            ScanNormalizedPoint(x: 0.9, y: 0.9),
            ScanNormalizedPoint(x: 0.9, y: 0.1),
            ScanNormalizedPoint(x: 0.1, y: 0.9)
        ]
        geometry.perspectiveCorrectionEnabled = true

        do {
            _ = try await processor.applyGeometry(
                to: page,
                geometry: geometry,
                sessionDirectory: sessionDirectory
            )
            XCTFail("Expected invalid geometry")
        } catch let error as ScanDraftError {
            XCTAssertEqual(error, .invalidPageGeometry)
        }
    }
}
