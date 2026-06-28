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

    enum DrawingPlacement {
        case top
        case bottom
        case left
        case right
        case center
        case small
        case large
        case dot
        case loop
        case heavyPressure
        case lightPressure
        case longHorizontal
        case tall
    }

    static func makePlacementDrawing(
        _ placement: DrawingPlacement,
        color: UIColor = SignatureInkColor.defaultInk.uiColor
    ) -> PKDrawing {
        switch placement {
        case .top:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 14), color: color, span: 70)
        case .bottom:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 286), color: color, span: 70)
        case .left:
            return makeLocalizedStroke(center: CGPoint(x: 14, y: 150), color: color, span: 70)
        case .right:
            return makeLocalizedStroke(center: CGPoint(x: 386, y: 150), color: color, span: 70)
        case .center:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 150), color: color, span: 90)
        case .small:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 150), color: color, span: 24, strokeWidth: 2)
        case .large:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 150), color: color, span: 260, strokeWidth: 5)
        case .dot:
            return makeDotDrawing(center: CGPoint(x: 200, y: 150), color: color)
        case .loop:
            return makeLoopDrawing(center: CGPoint(x: 200, y: 150), color: color)
        case .heavyPressure:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 150), color: color, span: 120, strokeWidth: 14)
        case .lightPressure:
            return makeLocalizedStroke(
                center: CGPoint(x: 200, y: 150),
                color: color,
                span: 120,
                strokeWidth: 2,
                opacity: 1
            )
        case .longHorizontal:
            return makeLocalizedStroke(center: CGPoint(x: 200, y: 150), color: color, span: 320, strokeWidth: 3)
        case .tall:
            return makeTallStroke(center: CGPoint(x: 200, y: 150), color: color, span: 180)
        }
    }

    static func transparentMargins(in image: UIImage) -> (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)? {
        guard let borders = transparentBorderWidths(in: image) else { return nil }
        return borders
    }

    static func transparentBorderWidths(
        in image: UIImage,
        alphaThreshold: UInt8 = 0
    ) -> (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)? {
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

        func rowHasInk(_ y: Int) -> Bool {
            for x in 0..<width where pixelData[(y * width + x) * 4 + 3] > alphaThreshold {
                return true
            }
            return false
        }

        func columnHasInk(_ x: Int) -> Bool {
            for y in 0..<height where pixelData[(y * width + x) * 4 + 3] > alphaThreshold {
                return true
            }
            return false
        }

        var top = 0
        while top < height, !rowHasInk(top) { top += 1 }

        var bottom = 0
        var row = height - 1
        while row >= 0, !rowHasInk(row) {
            bottom += 1
            row -= 1
        }

        var left = 0
        while left < width, !columnHasInk(left) { left += 1 }

        var right = 0
        var column = width - 1
        while column >= 0, !columnHasInk(column) {
            right += 1
            column -= 1
        }

        let scale = image.scale
        return (
            top: CGFloat(top) / scale,
            bottom: CGFloat(bottom) / scale,
            left: CGFloat(left) / scale,
            right: CGFloat(right) / scale
        )
    }

    static func referenceInkBounds(for drawing: PKDrawing) -> CGRect? {
        SignatureRenderer.renderedInkBounds(from: drawing)
    }

    static func assertTightCrop(
        for drawing: PKDrawing,
        horizontalPadding: CGFloat = SignatureRenderer.defaultHorizontalPadding,
        verticalPadding: CGFloat = SignatureRenderer.defaultVerticalPadding,
        tolerance: CGFloat = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let image = try XCTUnwrap(
            SignatureRenderer.image(
                from: drawing,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            ),
            file: file,
            line: line
        )
        let referenceInk = try XCTUnwrap(referenceInkBounds(for: drawing), file: file, line: line)
        let borders = try XCTUnwrap(transparentBorderWidths(in: image), file: file, line: line)

        XCTAssertLessThanOrEqual(borders.top, verticalPadding + tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(borders.bottom, verticalPadding + tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(borders.left, horizontalPadding + tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(borders.right, horizontalPadding + tolerance, file: file, line: line)

        XCTAssertEqual(image.size.width, referenceInk.width + horizontalPadding * 2, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(image.size.height, referenceInk.height + verticalPadding * 2, accuracy: tolerance, file: file, line: line)
        XCTAssertTrue(imageHasInkPixels(image), file: file, line: line)
        XCTAssertTrue(hasTransparentBackground(image), file: file, line: line)
    }

    private static func makeDotDrawing(center: CGPoint, color: UIColor) -> PKDrawing {
        let point = PKStrokePoint(
            location: center,
            timeOffset: 0,
            size: CGSize(width: 8, height: 8),
            opacity: 1,
            force: 1,
            azimuth: 0,
            altitude: 0
        )
        let path = PKStrokePath(controlPoints: [point], creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.pen, color: color), path: path)
        return PKDrawing(strokes: [stroke])
    }

    private static func makeLoopDrawing(center: CGPoint, color: UIColor) -> PKDrawing {
        let radius: CGFloat = 36
        let points = (0..<16).map { index -> PKStrokePoint in
            let angle = (CGFloat(index) / 16) * (.pi * 2)
            return PKStrokePoint(
                location: CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                ),
                timeOffset: TimeInterval(index) * 0.01,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.pen, color: color), path: path)
        return PKDrawing(strokes: [stroke])
    }

    private static func makeTallStroke(center: CGPoint, color: UIColor, span: CGFloat) -> PKDrawing {
        let halfSpan = span / 2
        let points = [
            PKStrokePoint(
                location: CGPoint(x: center.x, y: center.y - halfSpan),
                timeOffset: 0,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: center.x + 8, y: center.y),
                timeOffset: 0.05,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: center.x, y: center.y + halfSpan),
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

    private static func makeLocalizedStroke(
        center: CGPoint,
        color: UIColor,
        span: CGFloat,
        strokeWidth: CGFloat = 3,
        opacity: CGFloat = 1
    ) -> PKDrawing {
        let halfSpan = span / 2
        let points = [
            PKStrokePoint(
                location: CGPoint(x: center.x - halfSpan, y: center.y + 2),
                timeOffset: 0,
                size: CGSize(width: strokeWidth, height: strokeWidth),
                opacity: opacity,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: center.x, y: center.y - 2),
                timeOffset: 0.05,
                size: CGSize(width: strokeWidth, height: strokeWidth),
                opacity: opacity,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
            PKStrokePoint(
                location: CGPoint(x: center.x + halfSpan, y: center.y + 1),
                timeOffset: 0.1,
                size: CGSize(width: strokeWidth, height: strokeWidth),
                opacity: opacity,
                force: 1,
                azimuth: 0,
                altitude: 0
            ),
        ]

        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.pen, color: color), path: path)
        return PKDrawing(strokes: [stroke])
    }

    static func maxAlpha(in image: UIImage) -> UInt8 {
        guard let cgImage = image.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return 0 }

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
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var maxValue: UInt8 = 0
        for index in stride(from: 3, to: pixelData.count, by: 4) {
            maxValue = max(maxValue, pixelData[index])
        }
        return maxValue
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
        let paddedImage = try XCTUnwrap(
            SignatureRenderer.image(
                from: drawing,
                horizontalPadding: SignatureRenderer.defaultHorizontalPadding,
                verticalPadding: SignatureRenderer.defaultVerticalPadding
            )
        )
        let tightImage = try XCTUnwrap(
            SignatureRenderer.image(from: drawing, horizontalPadding: 0, verticalPadding: 0)
        )

        XCTAssertGreaterThan(paddedImage.size.width, tightImage.size.width)
        XCTAssertGreaterThan(paddedImage.size.height, tightImage.size.height)
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
        XCTAssertTrue(source.contains("opaquePixelBounds"))
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

    func testLightPressureDrawingRendersDetectableInk() throws {
        let drawing = SignatureTestHelpers.makePlacementDrawing(.lightPressure)
        XCTAssertFalse(drawing.bounds.isEmpty)

        let rendered = drawing.image(from: drawing.bounds.insetBy(dx: -40, dy: -40), scale: 2)
        let maxAlpha = SignatureTestHelpers.maxAlpha(in: rendered)
        XCTAssertGreaterThan(maxAlpha, 0, "Expected light-pressure stroke to render visible pixels")

        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        XCTAssertTrue(SignatureTestHelpers.imageHasInkPixels(image))
    }

    func testTightSignatureCropForEdgePlacements() throws {
        let placements: [SignatureTestHelpers.DrawingPlacement] = [
            .top, .bottom, .left, .right, .small, .large,
            .dot, .loop, .heavyPressure, .lightPressure, .longHorizontal, .tall,
        ]

        for placement in placements {
            try XCTContext.runActivity(named: "Tight crop for \(String(describing: placement))") { _ in
                try SignatureTestHelpers.assertTightCrop(
                    for: SignatureTestHelpers.makePlacementDrawing(placement)
                )
            }
        }
    }

    func testCropPaddingIsPreservedAroundInk() throws {
        let drawing = SignatureTestHelpers.makePlacementDrawing(.center)
        let horizontal = SignatureRenderer.defaultHorizontalPadding
        let vertical = SignatureRenderer.defaultVerticalPadding
        let padded = try XCTUnwrap(
            SignatureRenderer.image(
                from: drawing,
                horizontalPadding: horizontal,
                verticalPadding: vertical
            )
        )
        let tight = try XCTUnwrap(
            SignatureRenderer.image(from: drawing, horizontalPadding: 0, verticalPadding: 0)
        )

        XCTAssertGreaterThan(padded.size.width, tight.size.width)
        XCTAssertGreaterThan(padded.size.height, tight.size.height)

        let margins = try XCTUnwrap(SignatureTestHelpers.transparentBorderWidths(in: padded))
        XCTAssertEqual(margins.top, vertical, accuracy: 1.5)
        XCTAssertEqual(margins.bottom, vertical, accuracy: 1.5)
        XCTAssertEqual(margins.left, horizontal, accuracy: 1.5)
        XCTAssertEqual(margins.right, horizontal, accuracy: 1.5)
    }

    func testSignatureCropHasNoExcessTransparentRowsOrColumns() throws {
        let drawing = SignatureTestHelpers.makePlacementDrawing(.longHorizontal)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        let borders = try XCTUnwrap(SignatureTestHelpers.transparentBorderWidths(in: image))

        XCTAssertLessThanOrEqual(borders.top, SignatureRenderer.defaultVerticalPadding + 1)
        XCTAssertLessThanOrEqual(borders.bottom, SignatureRenderer.defaultVerticalPadding + 1)
        XCTAssertLessThanOrEqual(borders.left, SignatureRenderer.defaultHorizontalPadding + 1)
        XCTAssertLessThanOrEqual(borders.right, SignatureRenderer.defaultHorizontalPadding + 1)
    }

    func testSignatureCropDoesNotClipRenderedInk() throws {
        let drawing = SignatureTestHelpers.makePlacementDrawing(.heavyPressure)
        try SignatureTestHelpers.assertTightCrop(for: drawing, tolerance: 2)
    }

    func testTransparentBackgroundPreservedAfterTightCrop() throws {
        let drawing = SignatureTestHelpers.makePlacementDrawing(.center)
        let image = try XCTUnwrap(SignatureRenderer.image(from: drawing))
        XCTAssertTrue(SignatureTestHelpers.hasTransparentBackground(image))
    }
}
