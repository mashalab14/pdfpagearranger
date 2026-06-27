import PencilKit
import UIKit
import XCTest
@testable import pdfpagearranger

enum SignatureTestHelpers {
    static func makeSampleDrawing(color: UIColor = SignatureInkColor.defaultInk.uiColor) -> PKDrawing {
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
        let stroke = PKStroke(ink: PKInk(.pen, color: color), path: path)
        return PKDrawing(strokes: [stroke])
    }

    static func imageHasInkPixels(_ image: UIImage) -> Bool {
        guard let average = averageInkColor(in: image) else { return false }
        let total = Int(average.red) + Int(average.green) + Int(average.blue)
        return average.alpha > 0 && total < 700
    }

    static func averageInkColor(in image: UIImage) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

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
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0
        var alphaTotal = 0
        var inkPixelCount = 0

        for index in stride(from: 0, to: pixelData.count, by: 4) {
            let alpha = pixelData[index + 3]
            let red = pixelData[index]
            let green = pixelData[index + 1]
            let blue = pixelData[index + 2]
            if alpha > 0, Int(red) + Int(green) + Int(blue) < 700 {
                redTotal += Int(red)
                greenTotal += Int(green)
                blueTotal += Int(blue)
                alphaTotal += Int(alpha)
                inkPixelCount += 1
            }
        }

        guard inkPixelCount > 0 else { return nil }

        return (
            red: UInt8(redTotal / inkPixelCount),
            green: UInt8(greenTotal / inkPixelCount),
            blue: UInt8(blueTotal / inkPixelCount),
            alpha: UInt8(alphaTotal / inkPixelCount)
        )
    }
}

final class SignatureCaptureRegressionTests: XCTestCase {
    private func signatureCaptureViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/SignatureCaptureView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func signatureRendererSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Services/SignatureRenderer.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testDefaultSignatureInkColorIsBlack() {
        XCTAssertEqual(SignatureInkColor.defaultInk, .black)
    }

    func testSignatureRendererProducesImageFromNonEmptyDrawing() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing()
        XCTAssertFalse(drawing.bounds.isEmpty)

        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertTrue(SignatureTestHelpers.imageHasInkPixels(image))
    }

    func testSignatureRendererUsesSelectedBlueInkColor() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.blue.uiColor)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let average = try XCTUnwrap(SignatureTestHelpers.averageInkColor(in: image))

        XCTAssertGreaterThan(average.blue, average.red)
        XCTAssertGreaterThan(average.blue, average.green)
    }

    func testSignatureRendererUsesSelectedDarkGrayInkColor() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.darkGray.uiColor)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let average = try XCTUnwrap(SignatureTestHelpers.averageInkColor(in: image))

        let components = Int(average.red) + Int(average.green) + Int(average.blue)
        XCTAssertGreaterThan(components, 0)
        XCTAssertLessThan(components, 600)
    }

    func testSignatureCanvasBorderOverlayDoesNotBlockTouches() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(
            source.contains(".allowsHitTesting(false)"),
            "Decorative canvas border must not intercept touches meant for PKCanvasView"
        )
    }

    func testSignatureCanvasUsesWhiteLightModeBackground() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(source.contains("canvas.backgroundColor = .white"))
        XCTAssertTrue(source.contains("canvas.overrideUserInterfaceStyle = .light"))
        XCTAssertTrue(source.contains("canvas.isOpaque = true"))
    }

    func testSignatureRendererExportsInLightTraitCollection() throws {
        let source = try signatureRendererSource()
        XCTAssertTrue(source.contains("userInterfaceStyle: .light"))
    }

    func testUseSignatureDisabledWhenDrawingIsEmpty() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(source.contains(".disabled(!hasDrawing)"))
        XCTAssertTrue(source.contains("guard hasDrawing"))
    }

    func testClearRemovesDrawingAndDisablesUseSignature() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(source.contains("canvasView?.drawing = PKDrawing()"))
        XCTAssertTrue(source.contains("hasDrawing = false"))
    }
}
