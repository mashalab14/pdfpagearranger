import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class ScanPageGeometryEngineRegressionTests: XCTestCase {
    func testFullBoundsCornersAreValidAndOrdered() {
        let corners = ScanPageGeometryEngine.fullBoundsCorners()

        XCTAssertEqual(corners.count, 4)
        XCTAssertEqual(corners[0].x, corners[0].y, accuracy: 0.001)
        XCTAssertEqual(corners[1].x, 1 - corners[0].x, accuracy: 0.001)
        XCTAssertTrue(ScanPageGeometryEngine.validateCorners(corners).isSuccess)
    }

    func testNormalizedPixelRoundTripPortrait() {
        let imageSize = CGSize(width: 800, height: 1200)
        let point = ScanNormalizedPoint(x: 0.25, y: 0.75)

        let pixel = ScanPageGeometryEngine.normalizedToPixel(point, imageSize: imageSize)
        let roundTrip = ScanPageGeometryEngine.pixelToNormalized(pixel, imageSize: imageSize)

        XCTAssertEqual(roundTrip.x, point.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, point.y, accuracy: 0.001)
    }

    func testPreviewCoordinateConversionWithLetterboxing() {
        let imageSize = CGSize(width: 1_000, height: 500)
        let containerSize = CGSize(width: 300, height: 400)
        let displayRect = ScanPageGeometryEngine.aspectFitDisplayRect(
            imageSize: imageSize,
            in: containerSize
        )
        let normalized = ScanNormalizedPoint(x: 0.5, y: 0.5)

        let previewPoint = ScanPageGeometryEngine.normalizedToPreview(
            normalized,
            displayRect: displayRect,
            imageSize: imageSize
        )
        let roundTrip = ScanPageGeometryEngine.previewToNormalized(
            previewPoint,
            displayRect: displayRect,
            imageSize: imageSize
        )

        XCTAssertEqual(roundTrip.x, normalized.x, accuracy: 0.01)
        XCTAssertEqual(roundTrip.y, normalized.y, accuracy: 0.01)
    }

    func testCoreImageCoordinateInvertsVerticalAxis() {
        let imageSize = CGSize(width: 200, height: 400)
        let normalized = ScanNormalizedPoint(x: 0.5, y: 0.25)
        let ciPoint = ScanPageGeometryEngine.normalizedToCoreImage(normalized, imageSize: imageSize)
        let roundTrip = ScanPageGeometryEngine.coreImageToNormalized(ciPoint, imageSize: imageSize)

        XCTAssertEqual(roundTrip.x, normalized.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, normalized.y, accuracy: 0.001)
    }

    func testCrossingCornersAreRejected() {
        let corners = [
            ScanNormalizedPoint(x: 0.1, y: 0.1),
            ScanNormalizedPoint(x: 0.9, y: 0.9),
            ScanNormalizedPoint(x: 0.9, y: 0.1),
            ScanNormalizedPoint(x: 0.1, y: 0.9)
        ]

        XCTAssertTrue(ScanPageGeometryEngine.validateCorners(corners).isFailure)
    }

    func testCollapsedCornersAreRejected() {
        let corners = [
            ScanNormalizedPoint(x: 0.4, y: 0.4),
            ScanNormalizedPoint(x: 0.41, y: 0.4),
            ScanNormalizedPoint(x: 0.41, y: 0.41),
            ScanNormalizedPoint(x: 0.4, y: 0.41)
        ]

        if case .failure(let reason) = ScanPageGeometryEngine.validateCorners(corners) {
            XCTAssertTrue(reason == .duplicateCorners || reason == .areaTooSmall)
        } else {
            XCTFail("Expected invalid geometry")
        }
    }

    func testRotationAdvancesInNinetyDegreeIncrements() {
        var geometry = ScanPageGeometry.default
        geometry = geometry.rotated()
        XCTAssertEqual(geometry.rotation, 90)
        geometry = geometry.rotated()
        geometry = geometry.rotated()
        geometry = geometry.rotated()
        XCTAssertEqual(geometry.rotation, 0)
    }
}

private extension Result where Success == [ScanNormalizedPoint], Failure == ScanPageGeometryValidationFailure {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool { !isSuccess }
}
