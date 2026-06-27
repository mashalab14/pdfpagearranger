import PencilKit
import XCTest
@testable import pdfpagearranger

final class SignatureCaptureRegressionTests: XCTestCase {
    private func signatureCaptureViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/SignatureCaptureView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testSignatureCanvasBorderOverlayDoesNotBlockTouches() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(
            source.contains(".allowsHitTesting(false)"),
            "Decorative canvas border must not intercept touches meant for PKCanvasView"
        )
    }

    func testSignatureRendererProducesImageFromNonEmptyDrawing() throws {
        let drawing = try makeSampleSignatureDrawing()
        XCTAssertFalse(drawing.bounds.isEmpty)

        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertTrue(imageHasInkPixels(image))
    }

    private func makeSampleSignatureDrawing() throws -> PKDrawing {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 12, y: 40),
                timeOffset: 0,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: 48, y: 36),
                timeOffset: 0.05,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: 96, y: 42),
                timeOffset: 0.1,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
        ]

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: path)
        return PKDrawing(strokes: [stroke])
    }

    private func imageHasInkPixels(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return false }

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for index in stride(from: 0, to: pixelData.count, by: 4) {
            let alpha = pixelData[index + 3]
            let red = pixelData[index]
            let green = pixelData[index + 1]
            let blue = pixelData[index + 2]
            if alpha > 0, Int(red) + Int(green) + Int(blue) < 765 {
                return true
            }
        }

        return false
    }
}
