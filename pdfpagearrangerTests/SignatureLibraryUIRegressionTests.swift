import XCTest
@testable import pdfpagearranger

@MainActor
final class SignatureLibraryUIRegressionTests: XCTestCase {
    private var tempDirectories: [URL] = []
    private var store: SignatureLibraryStore!
    private var viewModel: PDFEditorViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let directory = try SignatureAssetTestFactory.makeTemporaryStoreDirectory()
        tempDirectories.append(directory)
        store = SignatureLibraryStore(rootDirectory: directory)
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.url(for: .onePage)
        tempDirectories.append(url)
        await viewModel.importPDF(from: url)
    }

    override func tearDown() async throws {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        store = nil
        viewModel = nil
        try await super.tearDown()
    }

    func testEmptyLibraryStateHasNoSavedSignatures() {
        XCTAssertTrue(store.listSignatures().isEmpty)
    }

    func testCreateFirstSignatureAppearsInLibrary() throws {
        let imageData = SignatureAssetTestFactory.makePNGData()

        let asset = try store.saveSignature(
            imageData: imageData,
            sourceType: .drawn,
            displayName: "Signature"
        )

        let listed = store.listSignatures()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.id, asset.id)
    }

    func testMultipleSignaturesAreListed() throws {
        _ = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .black),
            sourceType: .drawn,
            displayName: "First"
        )
        _ = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .drawn,
            displayName: "Second"
        )
        _ = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .red),
            sourceType: .drawn,
            displayName: "Third"
        )

        XCTAssertEqual(store.listSignatures().count, 3)
    }

    func testTapSavedSignaturePlacesOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let imageData = SignatureAssetTestFactory.makePNGData()
        let asset = try store.saveSignature(imageData: imageData, sourceType: .drawn)
        let loadedData = try XCTUnwrap(store.loadImageData(for: asset))
        let image = try XCTUnwrap(UIImage(data: loadedData))

        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: 0.77)

        let overlays = viewModel.overlayObjects(for: page.id)
        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(overlays.first?.type, .signature)
    }

    func testSaveAndUseStoresSignatureAndPlacesOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let image = OverlayTestFactory.makeSignatureImage()
        let pngData = try XCTUnwrap(image.pngData())

        let asset = try store.saveSignature(imageData: pngData, sourceType: .drawn)
        viewModel.addSignatureOverlay(to: page.id, image: image, pageAspectRatio: 0.77)

        XCTAssertEqual(store.listSignatures().count, 1)
        XCTAssertEqual(store.getSignature(id: asset.id)?.sourceType, .drawn)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.type, .signature)
    }

    func testExistingSignatureOverlayRegressionStillPasses() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let signature = OverlayTestFactory.seedSignature(on: viewModel, pageItemID: page.id)

        XCTAssertEqual(signature.type, .signature)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
    }

    private func signatureLibraryViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/SignatureLibraryView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func pageEditorViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageEditorView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func signatureCaptureViewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/SignatureCaptureView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testSignatureLibraryViewShowsEmptyStateCopy() throws {
        let source = try signatureLibraryViewSource()
        XCTAssertTrue(source.contains("No saved signatures"))
        XCTAssertTrue(source.contains("Create Signature"))
        XCTAssertTrue(source.contains("signatureLibraryEmptyState"))
    }

    func testSignatureLibraryViewShowsCreateNewButtonWhenPopulated() throws {
        let source = try signatureLibraryViewSource()
        XCTAssertTrue(source.contains("Create New Signature"))
        XCTAssertTrue(source.contains("signatureLibraryCreateNewButton"))
    }

    func testPageEditorOpensSignatureLibraryInsteadOfCapture() throws {
        let source = try pageEditorViewSource()
        XCTAssertTrue(source.contains("SignatureLibraryView"))
        XCTAssertTrue(source.contains("showSignatureLibrary"))
        XCTAssertFalse(source.contains("showSignatureCapture"))
    }

    func testSignatureCaptureUsesSaveAndUseButtonLabel() throws {
        let source = try signatureCaptureViewSource()
        XCTAssertTrue(source.contains("Save & Use"))
        XCTAssertTrue(source.contains("signatureSaveAndUseButton"))
    }

    func testSignatureLibrarySupportsRenameAndDeleteContextMenu() throws {
        let source = try signatureLibraryViewSource()
        XCTAssertTrue(source.contains(".contextMenu"))
        XCTAssertTrue(source.contains("Rename"))
        XCTAssertTrue(source.contains("Delete"))
        XCTAssertTrue(source.contains("renameSignature"))
        XCTAssertTrue(source.contains("Rename Signature"))
    }
}
