import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftImmediatePhotosPickerRegressionTests: XCTestCase {
    func testPhotosAcquisitionViewDoesNotPresentPickerLocally() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Views/ScanDraftPhotosAcquisitionView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains(".photosPicker"))
        XCTAssertFalse(source.contains("isPhotosPickerPresented"))
        XCTAssertFalse(source.contains("navigationTitle(\"Import Photos\")"))
        XCTAssertFalse(source.contains("Import Photos"))
        XCTAssertTrue(source.contains("Color.clear"))
    }

    func testContentViewPresentsPhotosPickerFromHome() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("isPhotosPickerPresented"))
        XCTAssertTrue(source.contains(".photosPicker"))
        XCTAssertTrue(source.contains("beginPhotosImportFlow()"))
        XCTAssertTrue(source.contains("isScanDraftReviewPresented"))
    }

    func testBeginPhotosImportFlowPresentsPickerWithoutNavigation() {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)

        let ready = viewModel.beginPhotosImportFlow()

        XCTAssertTrue(ready)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertTrue(viewModel.isPhotosPickerPresented)
        XCTAssertNotNil(viewModel.document)
    }

    func testRequestPhotosImportDoesNotPresentPickerTwice() {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)

        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        viewModel.presentPhotosPickerIfNeeded()
        viewModel.presentPhotosPickerIfNeeded()

        XCTAssertTrue(viewModel.isPhotosPickerPresented)
    }

    func testBeginPhotosImportFlowCancellationCleansUpSession() {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)

        XCTAssertTrue(viewModel.beginPhotosImportFlow())
        viewModel.handlePhotosPickerCancelled()

        XCTAssertNil(viewModel.document)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
        XCTAssertFalse(viewModel.isPhotosPickerPresented)
    }
}
