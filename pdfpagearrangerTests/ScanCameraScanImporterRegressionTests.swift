import XCTest
@testable import pdfpagearranger

final class ScanCameraScanImporterRegressionTests: XCTestCase {
    func testSuccessfulImportCreatesOrderedCameraPagesWithFileReferences() throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanCameraScanImporter(storage: storage)
        let document = ScanDraftDocument()
        let sessionDirectory = try storage.createSessionDirectory(for: document.id)
        let scan = ScanCameraScanTestSupport.makeScanBridge(pageCount: 3)

        let pages = try importer.importVisionKitScan(
            scan,
            sessionDirectory: sessionDirectory,
            sessionDefaults: .neutral
        )

        XCTAssertEqual(pages.count, 3)
        XCTAssertTrue(pages.allSatisfy { $0.sourceType == .camera })
        XCTAssertEqual(Set(pages.map(\.id)).count, 3)
        XCTAssertTrue(pages.allSatisfy { $0.originalImage.relativePath.hasPrefix("originals/") })
        for page in pages {
            let url = page.originalImage.url(in: sessionDirectory)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testPersistenceFailureRollsBackPartialImport() throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanCameraScanImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())

        XCTAssertThrowsError(
            try importer.importPages(
                pageCount: 3,
                sourceType: .camera,
                sessionDirectory: sessionDirectory,
                sessionDefaults: .neutral
            ) { index in
                if index == 1 {
                    throw ScanDraftError.temporaryFileWriteFailure
                }
                return ScanDraftTestFactory.makeTestImageData()
            }
        ) { error in
            XCTAssertEqual(error as? ScanDraftError, .temporaryFileWriteFailure)
        }

        let originalsDirectory = sessionDirectory.appendingPathComponent("originals", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: originalsDirectory.path)
        XCTAssertTrue(files.isEmpty)
    }

    func testImportUsesFileReferencesWithoutRetainingImagesInModel() throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let importer = ScanCameraScanImporter(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())
        let scan = ScanCameraScanTestSupport.makeScanBridge(pageCount: 1)

        let pages = try importer.importVisionKitScan(
            scan,
            sessionDirectory: sessionDirectory,
            sessionDefaults: .neutral
        )

        let page = try XCTUnwrap(pages.first)
        XCTAssertFalse(page.originalImage.relativePath.isEmpty)
        XCTAssertGreaterThan(page.originalPixelSize.width, 0)
        XCTAssertGreaterThan(page.originalPixelSize.height, 0)
    }
}
