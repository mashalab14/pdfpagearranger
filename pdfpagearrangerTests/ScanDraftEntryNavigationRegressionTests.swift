import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftEntryNavigationRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var permissionChecker: MockScanCameraPermissionChecker!
    private var scannerAvailability: MockScanDocumentScannerAvailabilityChecker!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        permissionChecker = MockScanCameraPermissionChecker()
        scannerAvailability = MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: scannerAvailability
        )
    }

    func testBeginNewDocumentFlowDoesNotNavigateToRemovedScreens() throws {
        try viewModel.beginNewDocumentFlow()

        XCTAssertNotNil(viewModel.document)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testBeginCameraScanFlowPresentsScannerWithoutNavigation() async {
        permissionChecker.status = .authorized

        let ready = await viewModel.beginCameraScanFlow()

        XCTAssertTrue(ready)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertTrue(viewModel.isDocumentScannerPresented)
    }

    func testBeginCameraScanFlowFailureCleansUpEmptySession() async {
        permissionChecker.status = .denied

        let ready = await viewModel.beginCameraScanFlow()

        XCTAssertFalse(ready)
        XCTAssertNil(viewModel.document)
        XCTAssertFalse(viewModel.isDocumentScannerPresented)
    }

    func testBeginCameraScanFlowCancellationReturnsToEmptySession() async {
        permissionChecker.status = .authorized
        let ready = await viewModel.beginCameraScanFlow()
        XCTAssertTrue(ready)

        viewModel.handleVisionKitScanCancelled()

        XCTAssertNil(viewModel.document)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertFalse(viewModel.isDocumentScannerPresented)
    }

    func testBeginPhotosImportFlowNavigatesDirectlyToPhotosAcquisition() {
        XCTAssertTrue(viewModel.beginPhotosImportFlow())

        XCTAssertEqual(viewModel.navigationPath, [.photosAcquisition])
        XCTAssertNotNil(viewModel.document)
    }

    func testCameraImportStillReachesDraftReview() async throws {
        permissionChecker.status = .authorized
        let ready = await viewModel.beginCameraScanFlow()
        XCTAssertTrue(ready)

        await viewModel.handleVisionKitScanCompleted(
            ScanCameraScanTestSupport.makeScanBridge(pageCount: 1)
        )

        XCTAssertEqual(viewModel.navigationPath.last, .draftReview)
        XCTAssertEqual(viewModel.document?.pages.count, 1)
    }

    func testPhotosImportStillReachesDraftReview() async throws {
        XCTAssertTrue(viewModel.beginPhotosImportFlow())

        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )

        XCTAssertEqual(viewModel.navigationPath.last, .draftReview)
        XCTAssertEqual(viewModel.document?.pages.count, 1)
    }

    func testRemovedRoutesAreNotDefined() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Models/ScanDraftRoute.swift")
        )

        XCTAssertFalse(source.contains("case entry"))
        XCTAssertFalse(source.contains("case sourceSelection"))
        XCTAssertTrue(source.contains("case cameraAcquisition"))
        XCTAssertTrue(source.contains("case photosAcquisition"))
        XCTAssertTrue(source.contains("case draftReview"))
    }

    func testContentViewExposesDirectHomeEntryPoints() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/ContentView.swift")
        )

        XCTAssertTrue(source.contains("HomeScreenCopy"))
        XCTAssertTrue(source.contains("HomeScreenCopy.openPDF"))
        XCTAssertTrue(source.contains("HomeScreenCopy.scanToPDF"))
        XCTAssertTrue(source.contains("HomeScreenCopy.photoToPDF"))
        XCTAssertTrue(source.contains("openPDFButton"))
        XCTAssertTrue(source.contains("scanDocumentButton"))
        XCTAssertTrue(source.contains("importPhotosButton"))
        XCTAssertTrue(source.contains("ScanDraftEntryMode"))
        XCTAssertFalse(source.contains("New Document"))
        XCTAssertFalse(source.contains("Choose Source"))
    }

    func testScanDraftRootViewDoesNotReferenceRemovedScreens() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Views/ScanDraftRootView.swift")
        )

        XCTAssertFalse(source.contains("ScanDraftEntryView"))
        XCTAssertFalse(source.contains("ScanDraftSourceSelectionView"))
        XCTAssertFalse(source.contains("ScanDraftFlowRootPlaceholder"))
        XCTAssertFalse(source.contains("Choose Source"))
        XCTAssertFalse(source.contains("Create PDF"))
        XCTAssertTrue(source.contains("ScanDraftFlowEntryHost"))
        XCTAssertTrue(source.contains("ScanDocumentCameraScannerPresenter"))
    }
}

@MainActor
final class ScanDraftOpenPDFEntryRegressionTests: XCTestCase {
    func testOpenPDFUsesExistingEditorImportFlow() async throws {
        let pdfURL = try PDFTestFactory.url(for: .onePage)
        let editorViewModel = PDFEditorViewModel()

        await editorViewModel.importPDF(from: pdfURL)

        XCTAssertTrue(editorViewModel.hasDocument)
        XCTAssertEqual(editorViewModel.pageCount, 1)
        XCTAssertNil(editorViewModel.errorMessage)
    }
}
