import XCTest
@testable import pdfpagearranger

final class OverlayPageGeometryTests: XCTestCase {
    func testDisplayTransformAtZeroDegreesIsIdentity() {
        let result = OverlayPageGeometry.displayTransform(
            position: CGPoint(x: 0.25, y: 0.75),
            size: CGSize(width: 0.2, height: 0.1),
            objectRotation: 15,
            pageRotation: 0
        )

        XCTAssertEqual(result.position.x, 0.25, accuracy: 0.0001)
        XCTAssertEqual(result.position.y, 0.75, accuracy: 0.0001)
        XCTAssertEqual(result.size.width, 0.2, accuracy: 0.0001)
        XCTAssertEqual(result.size.height, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.rotation, 15, accuracy: 0.0001)
    }

    func testDisplayTransformAtNinetyDegreesMovesTopRightToBottomRight() {
        let topRight = CGPoint(x: 0.9, y: 0.1)
        let result = OverlayPageGeometry.displayTransform(
            position: topRight,
            size: CGSize(width: 0.2, height: 0.1),
            objectRotation: 0,
            pageRotation: 90
        )

        XCTAssertEqual(result.position.x, 0.9, accuracy: 0.0001)
        XCTAssertEqual(result.position.y, 0.9, accuracy: 0.0001)
        XCTAssertEqual(result.size.width, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.size.height, 0.2, accuracy: 0.0001)
        XCTAssertEqual(result.rotation, 90, accuracy: 0.0001)
    }

    func testDisplayTransformAtOneEightyDegrees() {
        let result = OverlayPageGeometry.displayTransform(
            position: CGPoint(x: 0.2, y: 0.3),
            size: CGSize(width: 0.4, height: 0.2),
            objectRotation: 10,
            pageRotation: 180
        )

        XCTAssertEqual(result.position.x, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.position.y, 0.7, accuracy: 0.0001)
        XCTAssertEqual(result.size.width, 0.4, accuracy: 0.0001)
        XCTAssertEqual(result.size.height, 0.2, accuracy: 0.0001)
        XCTAssertEqual(result.rotation, 190, accuracy: 0.0001)
    }

    func testDisplayTransformAtTwoSeventyDegrees() {
        let result = OverlayPageGeometry.displayTransform(
            position: CGPoint(x: 0.9, y: 0.1),
            size: CGSize(width: 0.2, height: 0.1),
            objectRotation: 0,
            pageRotation: 270
        )

        XCTAssertEqual(result.position.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.position.y, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.size.width, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.size.height, 0.2, accuracy: 0.0001)
        XCTAssertEqual(result.rotation, 270, accuracy: 0.0001)
    }

    func testStorageTransformRoundTripsAllRotations() {
        let rotations = [0, 90, 180, 270]
        let original = OverlayPageGeometry.Transformed(
            position: CGPoint(x: 0.35, y: 0.65),
            size: CGSize(width: 0.25, height: 0.15),
            rotation: 20
        )

        for pageRotation in rotations {
            let display = OverlayPageGeometry.displayTransform(
                position: original.position,
                size: original.size,
                objectRotation: original.rotation,
                pageRotation: pageRotation
            )
            let stored = OverlayPageGeometry.storageTransform(
                displayPosition: display.position,
                displaySize: display.size,
                objectRotation: display.rotation,
                pageRotation: pageRotation
            )

            XCTAssertEqual(stored.position.x, original.position.x, accuracy: 0.0001, "position x at \(pageRotation)°")
            XCTAssertEqual(stored.position.y, original.position.y, accuracy: 0.0001, "position y at \(pageRotation)°")
            XCTAssertEqual(stored.size.width, original.size.width, accuracy: 0.0001, "size width at \(pageRotation)°")
            XCTAssertEqual(stored.size.height, original.size.height, accuracy: 0.0001, "size height at \(pageRotation)°")
            XCTAssertEqual(stored.rotation, original.rotation, accuracy: 0.0001, "rotation at \(pageRotation)°")
        }
    }

    func testPageObjectExtensionsApplyDisplayAndStorageGeometry() {
        let object = OverlayTestFactory.makeImageOverlay(
            pageItemID: UUID(),
            position: CGPoint(x: 0.8, y: 0.2),
            size: CGSize(width: 0.3, height: 0.2)
        )

        let display = object.displayGeometry(pageRotation: 90)
        XCTAssertEqual(display.position.y, 0.8, accuracy: 0.0001)

        let restored = object.applyingStorageGeometry(display, pageRotation: 90)
        XCTAssertEqual(restored.position.x, object.position.x, accuracy: 0.0001)
        XCTAssertEqual(restored.position.y, object.position.y, accuracy: 0.0001)
    }
}
