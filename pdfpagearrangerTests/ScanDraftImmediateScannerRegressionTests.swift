import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftImmediateScannerRegressionTests: XCTestCase {
    func testCameraAcquisitionViewDoesNotPresentScannerLocally() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Views/ScanDraftCameraAcquisitionView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("ScanDocumentCameraScannerPresenter"))
        XCTAssertFalse(source.contains("presentDocumentScannerIfNeeded"))
        XCTAssertFalse(source.contains("navigationTitle(\"Scan Document\")"))
        XCTAssertTrue(source.contains("Color.clear"))
    }

    func testContentViewPresentsScannerFromHome() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("isDocumentScannerPresented"))
        XCTAssertTrue(source.contains("ScanDocumentCameraScannerPresenter"))
        XCTAssertTrue(source.contains("beginCameraScanFlow()"))
    }

    func testBeginCameraScanFlowDoesNotPushAcquisitionRoute() async {
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
    }

    func testRequestCameraScanDoesNotPresentScannerTwice() async {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let permissionChecker = MockScanCameraPermissionChecker()
        permissionChecker.status = .authorized
        let viewModel = ScanDraftSessionViewModel(
            storage: storage,
            permissionChecker: permissionChecker,
            scannerAvailability: MockScanDocumentScannerAvailabilityChecker(isDocumentScannerSupported: true)
        )

        let first = await viewModel.requestCameraScan(context: .newDocument)
        let second = await viewModel.requestCameraScan(context: .newDocument)

        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertTrue(viewModel.isDocumentScannerPresented)
    }
}
