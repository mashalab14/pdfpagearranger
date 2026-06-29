import PencilKit
import UIKit
import XCTest
@testable import pdfpagearranger

final class SignatureThicknessRegressionTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempDirectories: [URL] = []
    private var store: SignatureLibraryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "SignatureThicknessRegressionTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        SignatureCaptureSettings.clearStoredThickness(in: defaults)

        let directory = try SignatureAssetTestFactory.makeTemporaryStoreDirectory()
        tempDirectories.append(directory)
        store = SignatureLibraryStore(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        SignatureCaptureSettings.clearStoredThickness(in: defaults)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil

        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        store = nil
        try super.tearDownWithError()
    }

    func testDefaultThicknessIsMedium() {
        XCTAssertEqual(SignatureInkThickness.defaultThickness, .medium)
        XCTAssertEqual(SignatureCaptureSettings.storedThickness(in: defaults), .medium)
        XCTAssertNil(defaults.string(forKey: SignatureCaptureSettings.storageKey))
    }

    func testSelectingThinUpdatesDrawingToolWidth() {
        let tool = SignatureInkThickness.thin.inkingTool(color: .black)
        XCTAssertEqual(tool.width, 1.5, accuracy: 0.01)
    }

    func testSelectingMediumUpdatesDrawingToolWidth() {
        let tool = SignatureInkThickness.medium.inkingTool(color: .black)
        XCTAssertEqual(tool.width, 2.5, accuracy: 0.01)
    }

    func testSelectingThickUpdatesDrawingToolWidth() {
        let tool = SignatureInkThickness.thick.inkingTool(color: .black)
        XCTAssertEqual(tool.width, 4.0, accuracy: 0.01)
    }

    func testThicknessPersistsAcrossCaptureSessions() {
        SignatureCaptureSettings.setStoredThickness(.thick, in: defaults)

        XCTAssertEqual(
            defaults.string(forKey: SignatureCaptureSettings.storageKey),
            SignatureInkThickness.thick.rawValue
        )
        XCTAssertEqual(SignatureCaptureSettings.storedThickness(in: defaults), .thick)

        SignatureCaptureSettings.setStoredThickness(.thin, in: defaults)
        XCTAssertEqual(SignatureCaptureSettings.storedThickness(in: defaults), .thin)
    }

    func testInvalidStoredThicknessFallsBackToMedium() {
        defaults.set("extra-bold", forKey: SignatureCaptureSettings.storageKey)
        XCTAssertEqual(SignatureCaptureSettings.storedThickness(in: defaults), .medium)
    }

    func testExistingSignaturesWithoutThicknessMetadataStillLoad() throws {
        let legacyJSON = """
        [
          {
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "displayName": "Legacy",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z",
            "sourceType": "drawn",
            "imageFileName": "legacy.png",
            "thumbnailFileName": "legacy-thumb.png"
          }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let assets = try decoder.decode([SignatureAsset].self, from: legacyJSON)

        XCTAssertEqual(assets.count, 1)
        XCTAssertNil(assets[0].strokeThickness)
        XCTAssertEqual(assets[0].displayName, "Legacy")
    }

    func testSavedSignatureWithoutThicknessMetadataLoadsFromStore() throws {
        let imageData = SignatureAssetTestFactory.makePNGData()
        let asset = try store.saveSignature(imageData: imageData, sourceType: .drawn)

        XCTAssertNil(asset.strokeThickness)

        let reloaded = try XCTUnwrap(store.getSignature(id: asset.id))
        XCTAssertNil(reloaded.strokeThickness)
        XCTAssertNotNil(store.loadImageData(for: reloaded))
    }

    func testNewlySavedSignatureStoresThicknessMetadata() throws {
        let imageData = SignatureAssetTestFactory.makePNGData()
        let asset = try store.saveSignature(
            imageData: imageData,
            sourceType: .drawn,
            strokeThickness: .thick
        )

        XCTAssertEqual(asset.strokeThickness, .thick)

        let reloaded = try XCTUnwrap(store.getSignature(id: asset.id))
        XCTAssertEqual(reloaded.strokeThickness, .thick)
    }

    func testSignatureColorsStillWorkWithAllThicknesses() throws {
        for thickness in SignatureInkThickness.allCases {
            for color in SignatureInkColor.allCases {
                let tool = thickness.inkingTool(color: color)
                XCTAssertEqual(tool.width, thickness.strokeWidth, accuracy: 0.01)
                XCTAssertEqual(tool.color, color.uiColor)

                let drawing = SignatureTestHelpers.makeSampleDrawing(color: color.uiColor)
                let image = try XCTUnwrap(
                    SignatureRenderer.image(from: drawing),
                    "Expected rendered image for \(color.rawValue) at \(thickness.rawValue)"
                )
                XCTAssertTrue(
                    SignatureTestHelpers.imageHasInkPixels(image),
                    "Expected visible ink for \(color.rawValue) at \(thickness.rawValue)"
                )
            }
        }
    }

    @MainActor
    func testSavedSignatureCanStillBePlaced() async throws {
        let imageData = SignatureAssetTestFactory.makePNGData()
        let asset = try store.saveSignature(
            imageData: imageData,
            sourceType: .drawn,
            strokeThickness: .medium
        )

        let loadedData = try XCTUnwrap(store.loadImageData(for: asset))
        let image = try XCTUnwrap(UIImage(data: loadedData))

        let viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempDirectories.append(url)
        await viewModel.importPDF(from: url)

        let page = try XCTUnwrap(viewModel.pages.first)
        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: 0.77)

        let overlays = viewModel.overlayObjects(for: page.id)
        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(overlays.first?.type, .signature)
    }

    func testSignatureCaptureViewDefinesThicknessSelector() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(source.contains("signatureThicknessPicker"))
        XCTAssertTrue(source.contains("SignatureInkThickness.allCases"))
        XCTAssertTrue(source.contains("thickness.accessibilityIdentifier"))
        XCTAssertTrue(source.contains("selectedThickness"))
        XCTAssertTrue(source.contains("SignatureCaptureSettings.setStoredThickness"))
    }

    func testChangingThicknessDoesNotClearDrawing() throws {
        let source = try signatureCaptureViewSource()
        let thicknessButtonSection = source
            .components(separatedBy: "thicknessOption(for thickness:")[1]
            .components(separatedBy: "private var signatureColorPicker")[0]
        XCTAssertTrue(thicknessButtonSection.contains("selectedThickness = thickness"))
        XCTAssertFalse(thicknessButtonSection.contains("clearDrawing"))
    }

    private func signatureCaptureViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/SignatureCaptureView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
