import PencilKit
import UIKit
import XCTest
@testable import pdfpagearranger

enum SignatureTestHelpers {
    static func makeSampleDrawing(
        color: UIColor = SignatureInkColor.defaultInk.uiColor,
        offset: CGPoint = .zero
    ) -> PKDrawing {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 12 + offset.x, y: 40 + offset.y),
                timeOffset: 0,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: 48 + offset.x, y: 36 + offset.y),
                timeOffset: 0.05,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: 96 + offset.x, y: 42 + offset.y),
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

    static func makeCompactDrawing(color: UIColor = SignatureInkColor.defaultInk.uiColor) -> PKDrawing {
        makeSampleDrawing(color: color, offset: CGPoint(x: 400, y: 300))
    }

    static func imageHasInkPixels(_ image: UIImage) -> Bool {
        guard let average = averageInkColor(in: image) else { return false }
        let total = Int(average.red) + Int(average.green) + Int(average.blue)
        return average.alpha > 0 && total < 700
    }

    static func hasTransparentBackground(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: CGFloat(cgImage.width - 1), y: 0),
            CGPoint(x: 0, y: CGFloat(cgImage.height - 1)),
            CGPoint(x: CGFloat(cgImage.width - 1), y: CGFloat(cgImage.height - 1)),
        ]

        return corners.allSatisfy { alpha(at: $0, in: image) == 0 }
    }

    static func inkChannelValues(in image: UIImage) -> (red: Int, green: Int, blue: Int)? {
        guard let average = averageInkColor(in: image) else { return nil }
        return (Int(average.red), Int(average.green), Int(average.blue))
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

    static func alpha(at point: CGPoint, in image: UIImage) -> UInt8 {
        guard let cgImage = image.cgImage else { return 255 }

        let width = cgImage.width
        let height = cgImage.height
        let x = min(max(Int(point.x), 0), width - 1)
        let y = min(max(Int(point.y), 0), height - 1)

        var pixelData = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 255
        }

        context.draw(cgImage, in: CGRect(x: -x, y: -y, width: width, height: height))
        return pixelData[3]
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
        XCTAssertEqual(SignatureInkColor.allCases.first, .black)
    }

    func testEachPaletteColorRendersExpectedInk() throws {
        for color in SignatureInkColor.allCases {
            let drawing = SignatureTestHelpers.makeSampleDrawing(color: color.uiColor)
            let image = try XCTUnwrap(
                SignatureRenderer.image(from: drawing),
                "Expected rendered image for \(color.rawValue)"
            )
            XCTAssertTrue(
                SignatureTestHelpers.imageHasInkPixels(image),
                "Expected visible ink for \(color.rawValue)"
            )
        }
    }

    func testPaletteBlueInkDominatesBlueChannel() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.blue.uiColor)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let channels = try XCTUnwrap(SignatureTestHelpers.inkChannelValues(in: image))
        XCTAssertGreaterThan(channels.blue, channels.red)
        XCTAssertGreaterThan(channels.blue, channels.green)
    }

    func testPaletteRedInkDominatesRedChannel() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.red.uiColor)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let channels = try XCTUnwrap(SignatureTestHelpers.inkChannelValues(in: image))
        XCTAssertGreaterThan(channels.red, channels.green)
        XCTAssertGreaterThan(channels.red, channels.blue)
    }

    func testPaletteGreenInkDominatesGreenChannel() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.green.uiColor)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let channels = try XCTUnwrap(SignatureTestHelpers.inkChannelValues(in: image))
        XCTAssertGreaterThan(channels.green, channels.red)
        XCTAssertGreaterThan(channels.green, channels.blue)
    }

    func testPalettePurpleInkDominatesBlueChannel() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing(color: SignatureInkColor.purple.uiColor)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let average = try XCTUnwrap(SignatureTestHelpers.averageInkColor(in: image))
        XCTAssertGreaterThan(Int(average.blue), Int(average.green))
    }

    func testGeneratedSignatureImageHasTransparentBackground() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing()
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        XCTAssertTrue(SignatureTestHelpers.hasTransparentBackground(image))
    }

    func testGeneratedSignatureImageIsCroppedToInkBounds() throws {
        let compactDrawing = SignatureTestHelpers.makeCompactDrawing()
        let compactImage = try XCTUnwrap(SignatureRenderer.image(from: compactDrawing))

        let largeCanvasDrawing = SignatureTestHelpers.makeSampleDrawing(offset: .zero)
        let largeCanvasImage = try XCTUnwrap(SignatureRenderer.image(from: largeCanvasDrawing))

        XCTAssertLessThan(compactImage.size.width, 250)
        XCTAssertLessThan(compactImage.size.height, 120)
        XCTAssertLessThanOrEqual(compactImage.size.width, largeCanvasImage.size.width + 1)
    }

    func testCroppedSignatureIncludesPaddingWithoutClippingStrokes() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing()
        let paddedImage = try XCTUnwrap(SignatureRenderer.image(from: drawing, padding: SignatureRenderer.defaultPadding))
        let tightImage = try XCTUnwrap(SignatureRenderer.image(from: drawing, padding: 0))

        XCTAssertGreaterThanOrEqual(paddedImage.size.width, tightImage.size.width)
        XCTAssertGreaterThanOrEqual(paddedImage.size.height, tightImage.size.height)
        XCTAssertTrue(SignatureTestHelpers.imageHasInkPixels(paddedImage))
    }

    func testEmptyDrawingReturnsNilImage() {
        XCTAssertNil(SignatureRenderer.image(from: PKDrawing()))
    }

    func testSignatureRendererProducesImageFromNonEmptyDrawing() throws {
        let drawing = SignatureTestHelpers.makeSampleDrawing()
        XCTAssertFalse(drawing.bounds.isEmpty)

        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertTrue(SignatureTestHelpers.imageHasInkPixels(image))
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
        XCTAssertTrue(source.contains("trimTransparentEdges"))
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
