import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class ScanOCRCoordinateConverterRegressionTests: XCTestCase {
    func testPortraitVisionToPDFYAxisConversion() {
        let pageSize = CGSize(width: 400, height: 600)
        let visionBox = CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1)
        let pdfRect = ScanOCRCoordinateConverter.pdfRect(
            fromVisionNormalizedBox: visionBox,
            pagePixelSize: pageSize
        )

        XCTAssertEqual(pdfRect.origin.x, 40, accuracy: 0.01)
        XCTAssertEqual(pdfRect.size.width, 200, accuracy: 0.01)
        XCTAssertEqual(pdfRect.size.height, 60, accuracy: 0.01)
        XCTAssertEqual(pdfRect.origin.y, (1.0 - 0.2 - 0.1) * 600, accuracy: 0.01)
    }

    func testLandscapeCoordinateConversion() {
        let pageSize = CGSize(width: 800, height: 400)
        let visionBox = CGRect(x: 0.25, y: 0.5, width: 0.4, height: 0.08)
        let pdfRect = ScanOCRCoordinateConverter.pdfRect(
            fromVisionNormalizedBox: visionBox,
            pagePixelSize: pageSize
        )

        XCTAssertEqual(pdfRect.width, 320, accuracy: 0.01)
        XCTAssertEqual(pdfRect.height, 32, accuracy: 0.01)
        XCTAssertEqual(pdfRect.minX, 200, accuracy: 0.01)
    }

    func testRoundTripConversionNearPageEdges() {
        let pageSize = CGSize(width: 612, height: 792)
        let boxes = [
            CGRect(x: 0, y: 0, width: 0.2, height: 0.05),
            CGRect(x: 0.8, y: 0.95, width: 0.2, height: 0.05),
            CGRect(x: 0.4, y: 0.45, width: 0.2, height: 0.04)
        ]

        for box in boxes {
            let pdfRect = ScanOCRCoordinateConverter.pdfRect(
                fromVisionNormalizedBox: box,
                pagePixelSize: pageSize
            )
            let roundTrip = ScanOCRCoordinateConverter.visionNormalizedBox(
                fromPDFRect: pdfRect,
                pagePixelSize: pageSize
            )
            XCTAssertEqual(roundTrip.origin.x, box.origin.x, accuracy: 0.0001)
            XCTAssertEqual(roundTrip.origin.y, box.origin.y, accuracy: 0.0001)
            XCTAssertEqual(roundTrip.size.width, box.size.width, accuracy: 0.0001)
            XCTAssertEqual(roundTrip.size.height, box.size.height, accuracy: 0.0001)
        }
    }

    func testDifferentImageAndPDFDimensionsScaleCorrectly() {
        let pageSize = CGSize(width: 1200, height: 1600)
        let visionBox = CGRect(x: 0.5, y: 0.5, width: 0.25, height: 0.02)
        let pdfRect = ScanOCRCoordinateConverter.pdfRect(
            fromVisionNormalizedBox: visionBox,
            pagePixelSize: pageSize
        )

        XCTAssertEqual(pdfRect.minX, 600, accuracy: 0.01)
        XCTAssertEqual(pdfRect.width, 300, accuracy: 0.01)
        XCTAssertEqual(pdfRect.height, 32, accuracy: 0.01)
    }
}
