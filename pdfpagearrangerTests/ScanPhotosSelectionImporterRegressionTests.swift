import XCTest
import UIKit
@testable import pdfpagearranger

final class ScanPhotosSelectionImporterRegressionTests: XCTestCase {
    func testSuccessfulSingleImageImportCreatesPhotosPage() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 1)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 1)

        let pages = try await importer.importPhotos(
            orderedItems: orderedItems,
            assetLoader: loader,
            sessionDirectory: sessionDirectory,
            sessionDefaults: .neutral
        )

        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.sourceType, .photos)
        XCTAssertTrue(pages.first?.originalImage.relativePath.hasPrefix("originals/") == true)
        let url = try XCTUnwrap(pages.first?.originalImage.url(in: sessionDirectory))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSuccessfulMultiImageImportPreservesSelectionOrder() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = [
            ScanOrderedPhotoImportItem(selectionIndex: 0, itemIdentifier: "first"),
            ScanOrderedPhotoImportItem(selectionIndex: 1, itemIdentifier: "second"),
            ScanOrderedPhotoImportItem(selectionIndex: 2, itemIdentifier: "third")
        ]
        let loader = MockScanPhotosAssetLoader()
        loader.payloadsByIdentifier = [
            "first": ScanDraftTestFactory.makeTestImageData(color: .red),
            "second": ScanDraftTestFactory.makeTestImageData(color: .green),
            "third": ScanDraftTestFactory.makeTestImageData(color: .blue)
        ]

        let pages = try await importer.importPhotos(
            orderedItems: orderedItems,
            assetLoader: loader,
            sessionDirectory: sessionDirectory,
            sessionDefaults: .neutral
        )

        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(loader.loadedIdentifiers, ["first", "second", "third"])
        XCTAssertEqual(Set(pages.map(\.id)).count, 3)
        XCTAssertTrue(pages.allSatisfy { $0.sourceType == .photos })
    }

    func testOutOfOrderInputStillImportsInSelectionIndexOrder() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = [
            ScanOrderedPhotoImportItem(selectionIndex: 2, itemIdentifier: "third"),
            ScanOrderedPhotoImportItem(selectionIndex: 0, itemIdentifier: "first"),
            ScanOrderedPhotoImportItem(selectionIndex: 1, itemIdentifier: "second")
        ]
        let loader = MockScanPhotosAssetLoader()
        loader.payloadsByIdentifier = [
            "first": ScanDraftTestFactory.makeTestImageData(color: .red),
            "second": ScanDraftTestFactory.makeTestImageData(color: .green),
            "third": ScanDraftTestFactory.makeTestImageData(color: .blue)
        ]

        let pages = try await importer.importPhotos(
            orderedItems: orderedItems,
            assetLoader: loader,
            sessionDirectory: sessionDirectory,
            sessionDefaults: .neutral
        )

        XCTAssertEqual(pages.count, 3)
        XCTAssertEqual(loader.loadedIdentifiers, ["first", "second", "third"])
    }

    func testFailureRollsBackEntireBatch() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 3)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 3)
        loader.failingIdentifiers = ["photo-1"]

        do {
            _ = try await importer.importPhotos(
                orderedItems: orderedItems,
                assetLoader: loader,
                sessionDirectory: sessionDirectory,
                sessionDefaults: .neutral
            )
            XCTFail("Expected import failure")
        } catch let error as ScanDraftError {
            XCTAssertEqual(error, .photosAssetLoadFailure)
        }

        let originalsDirectory = sessionDirectory.appendingPathComponent("originals", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: originalsDirectory.path)
        XCTAssertTrue(files.isEmpty)
    }

    func testUnsupportedAssetIsRejected() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 1)
        let loader = MockScanPhotosAssetLoader()
        loader.payloadsByIdentifier["photo-0"] = Data([0x00, 0x01, 0x02])

        do {
            _ = try await importer.importPhotos(
                orderedItems: orderedItems,
                assetLoader: loader,
                sessionDirectory: sessionDirectory,
                sessionDefaults: .neutral
            )
            XCTFail("Expected unsupported asset failure")
        } catch {
            XCTAssertTrue(error is ScanDraftError)
        }
    }

    func testImportReportsPageCountProgress() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 2)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)
        loader.loadDelayNanoseconds = 5_000_000
        var progressSnapshots: [ScanPhotosImportProgress] = []

        _ = try await importer.importPhotos(
            orderedItems: orderedItems,
            assetLoader: loader,
            sessionDirectory: sessionDirectory,
            sessionDefaults: .neutral,
            progressHandler: { progress in
                progressSnapshots.append(progress)
            }
        )

        XCTAssertTrue(progressSnapshots.contains(where: { $0.total == 2 && $0.completed == 0 }))
        XCTAssertEqual(progressSnapshots.last?.completed, 2)
        XCTAssertEqual(progressSnapshots.last?.total, 2)
    }

    func testCancellationDuringDelayedLoadingRollsBack() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanPhotosSelectionImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let orderedItems = ScanPhotosImportTestSupport.makeOrderedItems(count: 2)
        let loader = ScanPhotosImportTestSupport.makeLoader(count: 2)
        loader.loadDelayNanoseconds = 200_000_000
        let cancellationFlag = ScanImportCancellationFlag()

        let task = Task {
            try await importer.importPhotos(
                orderedItems: orderedItems,
                assetLoader: loader,
                sessionDirectory: sessionDirectory,
                sessionDefaults: .neutral,
                isCancelled: {
                    cancellationFlag.isCancelled || Task.isCancelled
                }
            )
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        cancellationFlag.cancel()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch let error as ScanDraftError {
            XCTAssertEqual(error, .photosImportCancelled)
        } catch is CancellationError {
            // Task cancellation is also acceptable for this boundary test.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let originalsDirectory = sessionDirectory.appendingPathComponent("originals", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: originalsDirectory.path)
        XCTAssertTrue(files.isEmpty)
    }
}
