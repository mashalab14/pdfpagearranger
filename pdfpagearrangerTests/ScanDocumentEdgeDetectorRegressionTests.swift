import XCTest
@testable import pdfpagearranger

final class ScanDocumentEdgeDetectorRegressionTests: XCTestCase {
    func testFailedDetectionReturnsNilWithoutThrowing() async throws {
        let detector = InMemoryScanDocumentEdgeDetector()
        detector.result = nil

        let outcome = try await detector.detectDocument(
            in: ScanDraftTestFactory.makeTestImageData()
        )

        XCTAssertNil(outcome)
        XCTAssertEqual(detector.callCount, 1)
    }

    func testSuccessfulDetectionReturnsNormalizedCorners() async throws {
        let detector = InMemoryScanDocumentEdgeDetector()
        detector.result = ScanDocumentEdgeDetectionResult(
            corners: ScanPageGeometryEngine.fullBoundsCorners(inset: 0.08),
            confidence: 0.92
        )

        let outcome = try await detector.detectDocument(in: ScanDraftTestFactory.makeTestImageData())
        let detection = try XCTUnwrap(outcome)

        XCTAssertEqual(detection.corners.count, 4)
        XCTAssertTrue(ScanPageGeometryEngine.validateCorners(detection.corners).isSuccess)
    }
}

private extension Result where Success == [ScanNormalizedPoint], Failure == ScanPageGeometryValidationFailure {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
