import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftHomeAcquisitionRegressionTests: XCTestCase {
    func testContentViewPresentsAcquisitionFromHome() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("beginCameraScanFlow()"))
        XCTAssertTrue(source.contains("beginPhotosImportFlow()"))
        XCTAssertTrue(source.contains("ScanDocumentCameraScannerPresenter"))
        XCTAssertTrue(source.contains(".photosPicker"))
        XCTAssertTrue(source.contains("isScanDraftReviewPresented"))
        XCTAssertFalse(source.contains("ScanDraftEntryMode"))
        XCTAssertFalse(source.contains("scanDraftEntryMode"))
        XCTAssertFalse(source.contains("presentationBackground(.clear)"))
    }

    func testScanDraftRootViewDoesNotOwnHomeAcquisition() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Views/ScanDraftRootView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("ScanDraftReviewView"))
        XCTAssertFalse(source.contains("ScanDraftFlowEntryHost"))
        XCTAssertFalse(source.contains("ScanDraftEntryMode"))
        XCTAssertFalse(source.contains(".photosPicker"))
        XCTAssertFalse(source.contains("ScanDocumentCameraScannerPresenter"))
        XCTAssertFalse(source.contains(".task(id: entryMode)"))
    }

    func testBeginCameraScanFlowDoesNotNavigateBeforeAcquisition() async {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let permissionChecker = MockScanCameraPermissionChecker()
        permissionChecker.status = .authorized
        let viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        )

        let ready = await viewModel.beginCameraScanFlow()

        XCTAssertTrue(ready)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertTrue(viewModel.isDocumentScannerPresented)
        XCTAssertTrue(viewModel.document?.isEmpty == true)
    }

    func testBeginPhotosImportFlowDoesNotNavigateBeforeSelection() {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)

        let ready = viewModel.beginPhotosImportFlow()

        XCTAssertTrue(ready)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertTrue(viewModel.isPhotosPickerPresented)
        XCTAssertTrue(viewModel.document?.isEmpty == true)
    }

    func testCameraCancellationLeavesEmptyDraftWithoutReviewNavigation() async {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let permissionChecker = MockScanCameraPermissionChecker()
        permissionChecker.status = .authorized
        let viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        )

        _ = await viewModel.beginCameraScanFlow()
        viewModel.handleVisionKitScanCancelled()

        XCTAssertNil(viewModel.document)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertFalse(viewModel.isDocumentScannerPresented)
    }

    func testPhotosCancellationLeavesEmptyDraftWithoutReviewNavigation() {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)

        _ = viewModel.beginPhotosImportFlow()
        viewModel.handlePhotosPickerCancelled()

        XCTAssertNil(viewModel.document)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertFalse(viewModel.isPhotosPickerPresented)
    }

    func testSuccessfulCameraImportNavigatesToDraftReviewRoot() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let permissionChecker = MockScanCameraPermissionChecker()
        permissionChecker.status = .authorized
        let viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        )

        _ = await viewModel.beginCameraScanFlow()
        await viewModel.handleVisionKitScanCompleted(
            ScanCameraScanTestSupport.makeScanBridge(pageCount: 1)
        )

        XCTAssertEqual(viewModel.document?.pages.count, 1)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testSuccessfulPhotosImportNavigatesToDraftReviewRoot() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)

        _ = viewModel.beginPhotosImportFlow()
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )

        XCTAssertEqual(viewModel.document?.pages.count, 1)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testCameraPermissionFailureCleansUpWithoutReviewNavigation() async {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let permissionChecker = MockScanCameraPermissionChecker()
        permissionChecker.status = .denied
        let viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        )

        let ready = await viewModel.beginCameraScanFlow()

        XCTAssertFalse(ready)
        XCTAssertNil(viewModel.document)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testBeginAddPagesPhotosImportStillNavigatesToAcquisitionRoute() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )
        XCTAssertTrue(viewModel.navigationPath.isEmpty)

        XCTAssertTrue(viewModel.beginAddPagesPhotosImport())

        XCTAssertEqual(viewModel.navigationPath.last, .photosAcquisition)
        XCTAssertTrue(viewModel.isPhotosPickerPresented)
    }
}
