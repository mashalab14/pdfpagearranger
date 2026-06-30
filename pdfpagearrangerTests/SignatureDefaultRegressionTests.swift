import XCTest
@testable import pdfpagearranger

final class SignatureDefaultRegressionTests: XCTestCase {
    private var tempDirectories: [URL] = []
    private var store: SignatureLibraryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let directory = try SignatureAssetTestFactory.makeTemporaryStoreDirectory()
        tempDirectories.append(directory)
        store = SignatureLibraryStore(rootDirectory: directory)
    }

    override func tearDownWithError() throws {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        store = nil
        try super.tearDownWithError()
    }

    func testSettingDefaultSignaturePersists() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn,
            displayName: "Default Candidate"
        )

        try store.setDefaultSignature(id: asset.id)

        XCTAssertEqual(store.defaultSignatureID(), asset.id)
        XCTAssertTrue(store.isDefaultSignature(id: asset.id))
    }

    func testOnlyOneDefaultSignatureAtATime() throws {
        let first = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .black),
            sourceType: .drawn,
            displayName: "First"
        )
        let second = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .drawn,
            displayName: "Second"
        )

        try store.setDefaultSignature(id: first.id)
        try store.setDefaultSignature(id: second.id)

        XCTAssertEqual(store.defaultSignatureID(), second.id)
        XCTAssertFalse(store.isDefaultSignature(id: first.id))
        XCTAssertTrue(store.isDefaultSignature(id: second.id))
    }

    func testDefaultSignaturePersistsAcrossStoreReload() throws {
        let directory = tempDirectories[0]
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )

        try store.setDefaultSignature(id: asset.id)

        let reloadedStore = SignatureLibraryStore(rootDirectory: directory)
        XCTAssertEqual(reloadedStore.defaultSignatureID(), asset.id)
        XCTAssertTrue(reloadedStore.isDefaultSignature(id: asset.id))
    }

    func testDeletingDefaultSignatureClearsDefault() throws {
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )

        try store.setDefaultSignature(id: asset.id)
        store.deleteSignature(id: asset.id)

        XCTAssertNil(store.defaultSignatureID())
        XCTAssertTrue(store.listSignatures().isEmpty)
    }

    func testQuickSignatureUsesStoredDefault() throws {
        let defaultAsset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .red),
            sourceType: .drawn,
            displayName: "Default"
        )
        _ = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .drawn,
            displayName: "Other"
        )

        try store.setDefaultSignature(id: defaultAsset.id)

        let resolved = try XCTUnwrap(store.resolveQuickSignatureAsset())
        XCTAssertEqual(resolved.id, defaultAsset.id)
        XCTAssertNotNil(store.quickSignatureImage())
    }

    func testQuickSignatureFallsBackToSingleSignatureWhenNoDefaultSet() throws {
        let only = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )

        XCTAssertNil(store.defaultSignatureID())

        let resolved = try XCTUnwrap(store.resolveQuickSignatureAsset())
        XCTAssertEqual(resolved.id, only.id)
        XCTAssertNotNil(store.quickSignatureImage())
    }

    func testQuickSignatureReturnsNilWhenNoSignaturesExist() {
        XCTAssertNil(store.resolveQuickSignatureAsset())
        XCTAssertNil(store.quickSignatureImage())
    }

    func testQuickSignatureReturnsNilWhenMultipleSignaturesAndNoDefault() throws {
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

        XCTAssertNil(store.defaultSignatureID())
        XCTAssertNil(store.resolveQuickSignatureAsset())
        XCTAssertNil(store.quickSignatureImage())
        guard case .openLibrary(let showBanner) = store.resolveQuickSignatureResolution() else {
            return XCTFail("Expected library to open when multiple signatures have no Default Signature")
        }
        XCTAssertTrue(showBanner)
    }

    func testQuickSignatureWithNoSignaturesOpensEmptyLibrary() {
        guard case .openLibrary(let showBanner) = store.resolveQuickSignatureResolution() else {
            return XCTFail("Expected library to open when no signatures exist")
        }
        XCTAssertFalse(showBanner)
    }

    func testQuickSignatureWithExplicitDefaultPlacesImmediately() throws {
        let defaultAsset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .red),
            sourceType: .drawn
        )
        _ = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .drawn
        )
        try store.setDefaultSignature(id: defaultAsset.id)

        guard case .placeImmediately(let resolved) = store.resolveQuickSignatureResolution() else {
            return XCTFail("Expected immediate placement for explicit Default Signature")
        }
        XCTAssertEqual(resolved.id, defaultAsset.id)
    }

    func testQuickSignatureWithSingleSignatureAndNoDefaultPlacesImmediately() throws {
        let only = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )

        guard case .placeImmediately(let resolved) = store.resolveQuickSignatureResolution() else {
            return XCTFail("Expected immediate placement for single saved signature")
        }
        XCTAssertEqual(resolved.id, only.id)
    }

    func testNonDefaultSignaturesRemainSelectable() throws {
        let first = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .black),
            sourceType: .drawn,
            displayName: "First"
        )
        let second = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(color: .blue),
            sourceType: .drawn,
            displayName: "Second"
        )

        try store.setDefaultSignature(id: first.id)

        let secondData = try XCTUnwrap(store.loadImageData(for: second))
        XCTAssertNotNil(UIImage(data: secondData))
        XCTAssertFalse(store.isDefaultSignature(id: second.id))
    }

    func testSettingDefaultForMissingSignatureFailsGracefully() {
        XCTAssertThrowsError(
            try store.setDefaultSignature(id: UUID())
        ) { error in
            XCTAssertEqual(error as? SignatureLibraryStoreError, .signatureNotFound)
        }
    }

    func testStaleDefaultIDIsSanitizedOnRead() throws {
        let directory = tempDirectories[0]
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )
        try store.setDefaultSignature(id: asset.id)
        store.deleteSignature(id: asset.id)

        let reloadedStore = SignatureLibraryStore(rootDirectory: directory)
        XCTAssertNil(reloadedStore.defaultSignatureID())
    }
}

@MainActor
final class SignatureDefaultUIRegressionTests: XCTestCase {
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

    func testQuickSignaturePlacesDefaultOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let asset = try store.saveSignature(
            imageData: SignatureAssetTestFactory.makePNGData(),
            sourceType: .drawn
        )
        try store.setDefaultSignature(id: asset.id)

        let image = try XCTUnwrap(store.quickSignatureImage())
        let overlayID = viewModel.addSignatureOverlay(
            to: page.id,
            image: image,
            pageAspectRatio: 0.77
        )

        let overlays = viewModel.overlayObjects(for: page.id)
        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(overlays.first?.id, overlayID)
        XCTAssertEqual(overlays.first?.type, .signature)
    }

    func testAddMenuExposesQuickSignatureAndLibraryOptions() throws {
        let source = try pageAddOptionsSheetSource()
        XCTAssertTrue(source.contains("Quick Signature"))
        XCTAssertTrue(source.contains("Signature Library"))
        XCTAssertTrue(source.contains("addQuickSignatureOption"))
        XCTAssertTrue(source.contains("addSignatureLibraryOption"))
        XCTAssertFalse(source.contains("onSignatureTapped"))
    }

    func testSignatureLibraryShowsDefaultStarControls() throws {
        let source = try signatureLibraryViewSource()
        XCTAssertTrue(source.contains("star.fill"))
        XCTAssertTrue(source.contains("setDefault"))
        XCTAssertTrue(source.contains("@State private var defaultSignatureID"))
        XCTAssertTrue(source.contains("defaultSignatureID = asset.id"))
        XCTAssertTrue(source.contains("defaultSignatureID == asset.id"))
        XCTAssertTrue(source.contains("signatureLibraryDefaultButton_"))
        XCTAssertTrue(source.contains("signatureLibraryDefaultBadge_"))
        XCTAssertTrue(source.contains("Default Signature"))
        XCTAssertFalse(source.contains("\"Favorite\""))
    }

    func testSignatureLibraryShowsDefaultGuidanceBannerWhenRequested() throws {
        let source = try signatureLibraryViewSource()
        XCTAssertTrue(source.contains("showDefaultGuidanceBanner"))
        XCTAssertTrue(source.contains("signatureLibraryDefaultGuidanceBanner"))
        XCTAssertTrue(source.contains("Choose a default signature for one-tap signing."))
    }

    func testPageEditorSupportsQuickSignaturePlacement() throws {
        let source = try pageEditorViewSource()
        XCTAssertTrue(source.contains("handleQuickSignature"))
        XCTAssertTrue(source.contains("resolveQuickSignatureResolution"))
        XCTAssertTrue(source.contains("signatureLibraryShowsDefaultGuidance"))
        XCTAssertTrue(source.contains("beginSignaturePlacement"))
        XCTAssertTrue(source.contains("pageSelection = .overlay(overlayID)"))
    }

    func testDefaultSignatureStateUpdatesImmediatelyWithoutStoreReadInTile() throws {
        let source = try signatureLibraryViewSource()
        let tileSection = source
            .components(separatedBy: "signatureTile(for asset:")[1]
            .components(separatedBy: "private var renameAlertIsPresented")[0]
        XCTAssertTrue(tileSection.contains("let isDefault = defaultSignatureID == asset.id"))
        XCTAssertFalse(tileSection.contains("store.isDefaultSignature"))
    }

    private func pageAddOptionsSheetSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageAddOptionsSheet.swift")
        return try String(contentsOf: url, encoding: .utf8)
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
}
