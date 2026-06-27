import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class OverlayGeometryEngineTests: XCTestCase {
    func testDisplayGeometryAtZeroDegreesIsIdentity() {
        let result = OverlayGeometryEngine.displayGeometry(
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

    func testDisplayGeometryAtNinetyDegreesMovesTopRightToBottomRight() {
        let topRight = CGPoint(x: 0.9, y: 0.1)
        let result = OverlayGeometryEngine.displayGeometry(
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

    func testDisplayGeometryAtOneEightyDegrees() {
        let result = OverlayGeometryEngine.displayGeometry(
            position: CGPoint(x: 0.2, y: 0.3),
            size: CGSize(width: 0.4, height: 0.2),
            objectRotation: 10,
            pageRotation: 180
        )

        XCTAssertEqual(result.position.x, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.position.y, 0.7, accuracy: 0.0001)
        XCTAssertEqual(result.rotation, 190, accuracy: 0.0001)
    }

    func testDisplayGeometryAtTwoSeventyDegrees() {
        let result = OverlayGeometryEngine.displayGeometry(
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

    func testStorageGeometryRoundTripsAllRotations() {
        let rotations = [0, 90, 180, 270]
        let original = OverlayGeometryEngine.NormalizedGeometry(
            position: CGPoint(x: 0.35, y: 0.65),
            size: CGSize(width: 0.25, height: 0.15),
            rotation: 20
        )

        for pageRotation in rotations {
            let display = OverlayGeometryEngine.displayGeometry(
                position: original.position,
                size: original.size,
                objectRotation: original.rotation,
                pageRotation: pageRotation
            )
            let stored = OverlayGeometryEngine.storageGeometry(
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

    func testPageModeAndThumbnailLayoutsMatch() {
        let object = OverlayTestFactory.makeImageOverlay(
            pageItemID: UUID(),
            position: CGPoint(x: 0.4, y: 0.6),
            size: CGSize(width: 0.3, height: 0.2)
        )
        let renderSize = CGSize(width: 612, height: 792)

        let pageMode = OverlayGeometryEngine.pageModeLayout(
            for: object,
            pageRotation: 90,
            renderSize: renderSize
        )
        let thumbnail = OverlayGeometryEngine.thumbnailLayout(
            for: object,
            pageRotation: 90,
            renderSize: renderSize
        )

        XCTAssertEqual(pageMode.center.x, thumbnail.center.x, accuracy: 0.001)
        XCTAssertEqual(pageMode.center.y, thumbnail.center.y, accuracy: 0.001)
        XCTAssertEqual(pageMode.size.width, thumbnail.size.width, accuracy: 0.001)
        XCTAssertEqual(pageMode.size.height, thumbnail.size.height, accuracy: 0.001)
    }

    func testTopLeftLayoutMapsNormalizedCenterAndSize() {
        let object = OverlayTestFactory.makeImageOverlay(
            pageItemID: UUID(),
            position: CGPoint(x: 0.5, y: 0.25),
            size: CGSize(width: 0.2, height: 0.1)
        )
        let renderSize = CGSize(width: 400, height: 500)

        let layout = OverlayGeometryEngine.pageModeLayout(
            for: object,
            pageRotation: 0,
            renderSize: renderSize
        )

        XCTAssertEqual(layout.center.x, 200, accuracy: 0.001)
        XCTAssertEqual(layout.center.y, 125, accuracy: 0.001)
        XCTAssertEqual(layout.size.width, 80, accuracy: 0.001)
        XCTAssertEqual(layout.size.height, 50, accuracy: 0.001)
        XCTAssertEqual(layout.topLeftBounds.origin.x, 160, accuracy: 0.001)
        XCTAssertEqual(layout.topLeftBounds.origin.y, 100, accuracy: 0.001)
    }

    func testPDFLayoutMapsNormalizedCenterIntoMediaBoxCoordinates() {
        let object = OverlayTestFactory.makeImageOverlay(
            pageItemID: UUID(),
            position: CGPoint(x: 0.5, y: 0.25),
            size: CGSize(width: 0.2, height: 0.1)
        )
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        let layout = OverlayGeometryEngine.pdfLayout(
            for: object,
            pageRotation: 0,
            mediaBox: mediaBox
        )

        XCTAssertEqual(layout.center.x, 306, accuracy: 0.001)
        XCTAssertEqual(layout.center.y, 594, accuracy: 0.001)
        XCTAssertEqual(layout.size.width, 122.4, accuracy: 0.1)
        XCTAssertEqual(layout.size.height, 79.2, accuracy: 0.1)
    }

    func testPDFAndTopLeftLayoutsShareWidthAndHeightForSameRotation() {
        let object = OverlayTestFactory.makeImageOverlay(
            pageItemID: UUID(),
            position: CGPoint(x: 0.7, y: 0.3),
            size: CGSize(width: 0.25, height: 0.15)
        )
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let displaySize = OverlayGeometryEngine.displayRenderSize(for: 90, mediaBox: mediaBox)

        let topLeft = OverlayGeometryEngine.pageModeLayout(
            for: object,
            pageRotation: 90,
            renderSize: displaySize
        )
        let pdf = OverlayGeometryEngine.pdfLayout(
            for: object,
            pageRotation: 90,
            mediaBox: mediaBox
        )

        XCTAssertEqual(topLeft.size.width, pdf.size.width, accuracy: 0.001)
        XCTAssertEqual(topLeft.size.height, pdf.size.height, accuracy: 0.001)
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
