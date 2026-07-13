import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftSessionViewModelCameraRegressionTests: XCTestCase {
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

    func testSuccessfulNewScanCreatesPagesAndNavigatesToDraftReview() async throws {
        try viewModel.beginNewDocumentFlow()
        let sessionID = try XCTUnwrap(viewModel.document?.id)
        let sessionDirectory = storage.sessionDirectory(for: sessionID)
        let scan = ScanCameraScanTestSupport.makeScanBridge(pageCount: 2)

        await viewModel.handleVisionKitScanCompleted(scan)

        let document = try XCTUnwrap(viewModel.document)
        XCTAssertEqual(document.pages.count, 2)
        XCTAssertTrue(document.pages.allSatisfy { $0.sourceType == .camera })
        XCTAssertEqual(Set(document.pages.map(\.id)).count, 2)
        XCTAssertNotNil(document.selectedPageID)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        for page in document.pages {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: page.originalImage.url(in: sessionDirectory).path
                )
            )
        }
    }

    func testAddPagesAppendsToExistingDraftWithoutChangingExistingPages() async throws {
        try viewModel.beginNewDocumentFlow()
        await viewModel.handleVisionKitScanCompleted(ScanCameraScanTestSupport.makeScanBridge(pageCount: 1))

        let existingID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        var geometry = ScanPageGeometry.default
        geometry.rotation = 90
        viewModel.updatePageGeometry(id: existingID, geometry: geometry)

        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .enhanced
        viewModel.applyVisualAdjustments(adjustments, toPageIDs: [existingID])

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        await viewModel.handleVisionKitScanCompleted(ScanCameraScanTestSupport.makeScanBridge(pageCount: 2))

        let document = try XCTUnwrap(viewModel.document)
        XCTAssertEqual(document.pages.count, 3)
        XCTAssertEqual(document.pages.first?.id, existingID)
        XCTAssertEqual(document.pages.first?.geometry.rotation, 90)
        XCTAssertEqual(document.pages.first?.visualAdjustments.mode, .enhanced)
        XCTAssertTrue(document.pages.dropFirst().allSatisfy { $0.sourceType == .camera })
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testCancellationDoesNotCreatePagesOrErrorForNewDraft() async throws {
        try viewModel.beginNewDocumentFlow()
        let sessionID = try XCTUnwrap(viewModel.document?.id)

        viewModel.handleVisionKitScanCancelled()

        XCTAssertNil(viewModel.document)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(storage.sessionExists(for: sessionID))
    }

    func testCancellationPreservesExistingDraftWhenAddingPages() async throws {
        try viewModel.beginNewDocumentFlow()
        await viewModel.handleVisionKitScanCompleted(ScanCameraScanTestSupport.makeScanBridge(pageCount: 1))
        let beforeCount = viewModel.document?.pages.count

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        viewModel.handleVisionKitScanCancelled()

        XCTAssertEqual(viewModel.document?.pages.count, beforeCount)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testUnsupportedScannerProducesFeatureError() async {
        scannerAvailability = MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: false)
        viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: scannerAvailability
        )

        let ready = await viewModel.requestCameraScan(context: .newDocument)

        XCTAssertFalse(ready)
        XCTAssertEqual(viewModel.errorMessage, ScanDraftError.scannerUnsupported.localizedDescription)
    }

    func testDeniedPermissionProducesFeatureError() async {
        permissionChecker.status = .denied

        let ready = await viewModel.requestCameraScan(context: .newDocument)

        XCTAssertFalse(ready)
        XCTAssertEqual(viewModel.errorMessage, ScanDraftError.cameraPermissionDenied.localizedDescription)
    }

    func testRestrictedPermissionProducesFeatureError() async {
        permissionChecker.status = .restricted

        let ready = await viewModel.requestCameraScan(context: .newDocument)

        XCTAssertFalse(ready)
        XCTAssertEqual(viewModel.errorMessage, ScanDraftError.cameraPermissionRestricted.localizedDescription)
    }

    func testNotDeterminedPermissionRequestsAccessOnce() async {
        permissionChecker.status = .notDetermined
        permissionChecker.requestResult = .authorized

        let ready = await viewModel.requestCameraScan(context: .newDocument)

        XCTAssertTrue(ready)
        XCTAssertEqual(permissionChecker.requestAccessCallCount, 1)
        XCTAssertTrue(viewModel.isDocumentScannerPresented)
    }

    func testNotDeterminedFollowedByDenialProducesPermissionError() async {
        permissionChecker.status = .notDetermined
        permissionChecker.requestResult = .denied

        let ready = await viewModel.requestCameraScan(context: .newDocument)

        XCTAssertFalse(ready)
        XCTAssertEqual(viewModel.errorMessage, ScanDraftError.cameraPermissionDenied.localizedDescription)
    }

    func testDuplicateCompletionCallbacksImportOnce() async throws {
        try viewModel.beginNewDocumentFlow()
        let scan = ScanCameraScanTestSupport.makeScanBridge(pageCount: 2)

        await viewModel.handleVisionKitScanCompleted(scan)
        await viewModel.handleVisionKitScanCompleted(scan)

        XCTAssertEqual(viewModel.document?.pages.count, 2)
    }

    func testCancellationAfterCompletionDoesNotMutateDraft() async throws {
        try viewModel.beginNewDocumentFlow()
        let scan = ScanCameraScanTestSupport.makeScanBridge(pageCount: 1)

        await viewModel.handleVisionKitScanCompleted(scan)
        let pageCount = viewModel.document?.pages.count

        viewModel.handleVisionKitScanCancelled()

        XCTAssertEqual(viewModel.document?.pages.count, pageCount)
    }
}
