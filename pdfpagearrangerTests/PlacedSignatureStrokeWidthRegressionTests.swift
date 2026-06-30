import XCTest
@testable import pdfpagearranger

final class PlacedSignatureStrokeWidthRegressionTests: XCTestCase {
    func testClampsToTwoThroughThirty() {
        XCTAssertEqual(PlacedSignatureStrokeWidth.clamped(1), 2)
        XCTAssertEqual(PlacedSignatureStrokeWidth.clamped(2), 2)
        XCTAssertEqual(PlacedSignatureStrokeWidth.clamped(30), 30)
        XCTAssertEqual(PlacedSignatureStrokeWidth.clamped(40), 30)
    }

    func testLabelUsesIntegerPointsOnly() {
        XCTAssertEqual(PlacedSignatureStrokeWidth.label(for: 3), "3 pt")
        XCTAssertEqual(PlacedSignatureStrokeWidth.label(for: 12), "12 pt")
        XCTAssertFalse(PlacedSignatureStrokeWidth.label(for: 3).contains("."))
    }

    func testSteppersMoveByOnePoint() {
        XCTAssertEqual(PlacedSignatureStrokeWidth.decreased(from: 4), 3)
        XCTAssertEqual(PlacedSignatureStrokeWidth.increased(from: 4), 5)
        XCTAssertNil(PlacedSignatureStrokeWidth.decreased(from: 2))
        XCTAssertNil(PlacedSignatureStrokeWidth.increased(from: 30))
    }

    func testMapsLibraryThicknessToIntegerPoints() {
        XCTAssertEqual(PlacedSignatureStrokeWidth.points(for: .thin), 2)
        XCTAssertEqual(PlacedSignatureStrokeWidth.points(for: .medium), 3)
        XCTAssertEqual(PlacedSignatureStrokeWidth.points(for: .thick), 6)
    }
}
