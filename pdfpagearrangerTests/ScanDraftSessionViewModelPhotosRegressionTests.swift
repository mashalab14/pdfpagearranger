import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanDraftSessionViewModelPhotosRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        viewModel = ScanDraftSessionViewModel(storage: storage)
    }

    func testSuccessfulNewPhotosImportCreatesPagesAndNavigatesToDraftReview() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        let sessionID = try XCTUnwrap(viewModel.document?.id)
        let sessionDirectory = storage.sessionDirectory(for: sessionID)
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 2)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)

        await viewModel.handlePhotosSelection(orderedItems: orderedItems, assetLoader: loader)

        let document = try XCTUnwrap(viewModel.document)
        XCTAssertEqual(document.pages.count, 2)
        XCTAssertTrue(document.pages.allSatisfy { $0.sourceType == .photos })
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

    func testAddPhotosAppendsToExistingDraftWithoutChangingExistingPages() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )

        let existingID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        var geometry = ScanPageGeometry.default
        geometry.rotation = 90
        viewModel.updatePageGeometry(id: existingID, geometry: geometry)

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        await viewModel.handlePhotosSelection(
            orderedItems: [
                ScanOrderedPhotoImportItem(selectionIndex: 0, itemIdentifier: "photo-0"),
                ScanOrderedPhotoImportItem(selectionIndex: 1, itemIdentifier: "photo-1")
            ],
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 2)
        )

        let document = try XCTUnwrap(viewModel.document)
        XCTAssertEqual(document.pages.count, 3)
        XCTAssertEqual(document.pages.first?.id, existingID)
        XCTAssertEqual(document.pages.first?.geometry.rotation, 90)
        XCTAssertTrue(document.pages.dropFirst().allSatisfy { $0.sourceType == .photos })
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testPickerCancellationCreatesNoPagesOrErrorForNewDraft() throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        let sessionID = try XCTUnwrap(viewModel.document?.id)

        viewModel.handlePhotosPickerCancelled()

        XCTAssertNil(viewModel.document)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(storage.sessionExists(for: sessionID))
    }

    func testPickerCancellationPreservesExistingDraftWhenAddingPages() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )
        let beforeCount = viewModel.document?.pages.count

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        viewModel.handlePhotosPickerCancelled()

        XCTAssertEqual(viewModel.document?.pages.count, beforeCount)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testImportFailureRollsBackBatchWithoutNavigatingAsSuccess() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 2)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)
        loader.failingIdentifiers = ["photo-1"]

        await viewModel.handlePhotosSelection(orderedItems: orderedItems, assetLoader: loader)

        XCTAssertNil(viewModel.document)
        XCTAssertEqual(viewModel.errorMessage, ScanDraftError.photosAssetLoadFailure.localizedDescription)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testImportFailurePreservesExistingDraftPages() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )
        let existingID = try XCTUnwrap(viewModel.document?.pages.first?.id)

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)
        loader.failingIdentifiers = ["photo-1"]
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 2),
            assetLoader: loader
        )

        let document = try XCTUnwrap(viewModel.document)
        XCTAssertEqual(document.pages.count, 1)
        XCTAssertEqual(document.pages.first?.id, existingID)
    }

    func testDuplicateSelectionCallbacksImportOnce() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 2)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)

        await viewModel.handlePhotosSelection(orderedItems: orderedItems, assetLoader: loader)
        await viewModel.handlePhotosSelection(orderedItems: orderedItems, assetLoader: loader)

        XCTAssertEqual(viewModel.document?.pages.count, 2)
    }

    func testSecondImportCannotStartWhileFirstIsActive() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 1)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 1)
        loader.loadDelayNanoseconds = 200_000_000

        let first = Task {
            await viewModel.handlePhotosSelection(orderedItems: orderedItems, assetLoader: loader)
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(viewModel.isImportingPhotos)

        let orderedItems2 = ScanPhotosImportTestSupport.makeOrderedItems(count: 1)
        let loader2 = ScanPhotosImportTestSupport.makeLoader(count: 1)
        await viewModel.handlePhotosSelection(orderedItems: orderedItems2, assetLoader: loader2)

        await first.value
        XCTAssertEqual(viewModel.document?.pages.count, 1)
    }

    func testImportCancellationPreservesExistingDraft() async throws {
        try viewModel.beginNewDocumentFlow()
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )
        let existingCount = viewModel.document?.pages.count

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)
        loader.loadDelayNanoseconds = 200_000_000

        let importTask = Task {
            await viewModel.handlePhotosSelection(
                orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 2),
                assetLoader: loader
            )
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        viewModel.cancelPhotosImport()
        await importTask.value

        XCTAssertEqual(viewModel.document?.pages.count, existingCount)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isImportingPhotos)
    }
}
