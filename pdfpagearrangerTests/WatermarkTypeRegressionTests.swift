import CoreGraphics
import XCTest
@testable import pdfpagearranger

final class WatermarkTypeRegressionTests: XCTestCase {
    func testDefaultWatermarkTypeIsText() {
        XCTAssertEqual(WatermarkSettings.default.watermarkType, .text)
    }

    func testWatermarkTypeEnumSupportsTextAndImage() {
        XCTAssertEqual(WatermarkType.allCases, [.text, .image])
        XCTAssertEqual(WatermarkType.text.title, "Text")
        XCTAssertEqual(WatermarkType.image.title, "Image")
    }

    func testWatermarkViewUsesWatermarkTypeLabel() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkView.swift", subdirectory: "Views"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("Picker(\"Watermark Type\""))
        XCTAssertTrue(source.contains("watermarkTypePicker"))
        XCTAssertFalse(source.contains("watermarkContentTypePicker"))
    }

    func testImageTypeShowsImageSpecificControls() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkView.swift", subdirectory: "Views"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("watermarkType == .image"))
        XCTAssertTrue(source.contains("chooseWatermarkImageButton"))
        XCTAssertTrue(source.contains("chooseWatermarkFileButton"))
        XCTAssertTrue(source.contains("watermarkImagePreview"))
    }

    func testTextTypeShowsTextSpecificControls() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkView.swift", subdirectory: "Views"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("watermarkType == .text"))
        XCTAssertTrue(source.contains("watermarkTextField"))
        XCTAssertTrue(source.contains("watermarkColorPicker"))
    }

    func testSharedControlsPresentForAllWatermarkTypes() throws {
        let source = try String(
            contentsOf: projectSourceURL(file: "WatermarkView.swift", subdirectory: "Views"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("watermarkOpacitySlider"))
        XCTAssertTrue(source.contains("watermarkScaleStepper"))
        XCTAssertTrue(source.contains("watermarkRotationStepper"))
        XCTAssertTrue(source.contains("watermarkLayerPicker"))
        XCTAssertTrue(source.contains("watermarkCurrentPageStepper"))
        XCTAssertTrue(source.contains("watermarkRangeStartStepper"))
    }

    func testRendererBranchesByWatermarkType() throws {
        let rendererSource = try String(
            contentsOf: projectSourceURL(file: "WatermarkRenderer.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(rendererSource.contains("switch settings.watermarkType"))
        XCTAssertTrue(rendererSource.contains("case .text:"))
        XCTAssertTrue(rendererSource.contains("case .image:"))
    }

    func testGeometryEngineBranchesByWatermarkType() throws {
        let geometrySource = try String(
            contentsOf: projectSourceURL(file: "WatermarkGeometryEngine.swift", subdirectory: "Services"),
            encoding: .utf8
        )
        XCTAssertTrue(geometrySource.contains("switch settings.watermarkType"))
    }

    func testCodableUsesWatermarkTypeKey() throws {
        var settings = WatermarkSettings.default
        settings.watermarkType = .image
        settings.imageAssetID = UUID()

        let data = try JSONEncoder().encode(settings)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"watermarkType\":\"image\""))
        XCTAssertFalse(json.contains("\"contentType\""))

        let decoded = try JSONDecoder().decode(WatermarkSettings.self, from: data)
        XCTAssertEqual(decoded.watermarkType, .image)
    }

    func testCodableDecodesLegacyContentTypeKey() throws {
        let json = """
        {
          "isEnabled": true,
          "contentType": "image",
          "text": "LEGACY",
          "opacity": 0.5,
          "normalizedScale": 0.35,
          "color": {"red": 0.55, "green": 0.55, "blue": 0.55},
          "rotationDegrees": 45,
          "position": "center",
          "layer": "aboveContent",
          "applyScope": "allPages",
          "currentPageIndex": 1,
          "rangeStart": 1,
          "rangeEnd": 1
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let settings = try JSONDecoder().decode(WatermarkSettings.self, from: data)
        XCTAssertEqual(settings.watermarkType, .image)
    }

    @MainActor
    func testSwitchingWatermarkTypePreservesTextWhenReturningToText() async throws {
        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        defer { try? FileManager.default.removeItem(at: url) }
        await viewModel.importPDF(from: url)

        var textSettings = WatermarkSettings.default
        textSettings.text = "PRESERVED"
        viewModel.applyWatermark(textSettings)
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .text)
        XCTAssertEqual(viewModel.watermarkSettings.text, "PRESERVED")

        var imageSettings = WatermarkSettings.default
        imageSettings.watermarkType = .image
        viewModel.applyWatermark(
            imageSettings,
            watermarkImage: PDFTestFactory.makeTestImage()
        )
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .image)

        viewModel.undo()
        XCTAssertEqual(viewModel.watermarkSettings.watermarkType, .text)
        XCTAssertEqual(viewModel.watermarkSettings.text, "PRESERVED")
    }

    func testSharedGeometryUsesSameScaleForBothTypes() {
        let mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let scale: CGFloat = 0.30

        var textSettings = WatermarkSettings.default
        textSettings.normalizedScale = scale
        textSettings.text = "SCALE"

        var imageSettings = WatermarkSettings.default
        imageSettings.watermarkType = .image
        imageSettings.imageAssetID = UUID()
        imageSettings.normalizedScale = scale

        let image = PDFTestFactory.makeTestImage(size: CGSize(width: 100, height: 50))

        let textLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: textSettings,
            pageRotation: 0,
            mediaBox: mediaBox
        )
        let imageLayout = WatermarkGeometryEngine.normalizedLayout(
            settings: imageSettings,
            pageRotation: 0,
            mediaBox: mediaBox,
            image: image
        )

        XCTAssertEqual(textLayout?.scale, imageLayout?.scale)
        XCTAssertEqual(textLayout?.scale, scale)
    }

    private func projectSourceURL(file: String, subdirectory: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(file)
    }
}
