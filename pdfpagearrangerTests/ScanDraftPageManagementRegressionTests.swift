import XCTest
@testable import pdfpagearranger

final class ScanDraftPageManagementDocumentRegressionTests: XCTestCase {
    func testReorderPreservesPageIdentifiersGeometryAndFingerprints() {
        var document = makeDocumentWithDistinctPages(count: 3)
        let originalIDs = document.pages.map(\.id)
        let originalFingerprints = document.pages.map(\.processingFingerprint)
        let originalGeometry = document.pages.map(\.geometry)
        let originalVisuals = document.pages.map(\.visualAdjustments)
        let originalProcessed = document.pages.map(\.processedImage)
        document.selectPage(id: originalIDs[1])

        document.reorderPages(from: 0, to: 2)

        XCTAssertEqual(document.pages.map(\.id), [originalIDs[1], originalIDs[2], originalIDs[0]])
        XCTAssertEqual(document.pages.map(\.processingFingerprint), [
            originalFingerprints[1],
            originalFingerprints[2],
            originalFingerprints[0]
        ])
        XCTAssertEqual(document.pages.map(\.geometry), [
            originalGeometry[1],
            originalGeometry[2],
            originalGeometry[0]
        ])
        XCTAssertEqual(document.pages.map(\.visualAdjustments), [
            originalVisuals[1],
            originalVisuals[2],
            originalVisuals[0]
        ])
        XCTAssertEqual(document.pages.map(\.processedImage), [
            originalProcessed[1],
            originalProcessed[2],
            originalProcessed[0]
        ])
        XCTAssertEqual(document.selectedPageID, originalIDs[1])
        XCTAssertTrue(document.hasUnsavedChanges)
    }

    func testRemovePagesUpdatesSelectionToNearestRemainingPage() {
        var document = makeDocumentWithDistinctPages(count: 3)
        let ids = document.pages.map(\.id)
        document.selectPage(id: ids[1])

        let removed = document.removePages(ids: [ids[1]])

        XCTAssertEqual(removed, [ids[1]])
        XCTAssertEqual(document.pages.map(\.id), [ids[0], ids[2]])
        XCTAssertEqual(document.selectedPageID, ids[2])
    }

    func testRemoveMultiplePagesSelectsNearestRemainingPage() {
        var document = makeDocumentWithDistinctPages(count: 4)
        let ids = document.pages.map(\.id)
        document.selectPage(id: ids[2])

        let removed = document.removePages(ids: [ids[1], ids[2]])

        XCTAssertEqual(removed, Set([ids[1], ids[2]]))
        XCTAssertEqual(document.pages.map(\.id), [ids[0], ids[3]])
        XCTAssertEqual(document.selectedPageID, ids[3])
    }

    func testRemoveLastPageClearsSelection() throws {
        var document = makeDocumentWithDistinctPages(count: 1)
        let pageID = try XCTUnwrap(document.pages.first?.id)
        document.selectPage(id: pageID)

        XCTAssertEqual(document.removePages(ids: [pageID]), [pageID])
        XCTAssertTrue(document.isEmpty)
        XCTAssertNil(document.selectedPageID)
    }

    func testRotatePageUpdatesGeometryAndClearsProcessingOutput() throws {
        var document = makeDocumentWithDistinctPages(count: 2)
        let pageID = try XCTUnwrap(document.pages.first?.id)
        document.selectPage(id: pageID)

        document.rotatePage(id: pageID)

        let rotated = try XCTUnwrap(document.pages.first(where: { $0.id == pageID }))
        XCTAssertEqual(rotated.geometry.rotation, 90)
        XCTAssertEqual(rotated.processingState, .pending)
        XCTAssertNil(rotated.processingFingerprint)
        XCTAssertNil(rotated.processedImage)
        XCTAssertEqual(rotated.thumbnailState, .notGenerated)
        XCTAssertEqual(document.selectedPageID, pageID)

        let untouched = try XCTUnwrap(document.pages.last)
        XCTAssertEqual(untouched.geometry.rotation, 90)
        XCTAssertEqual(untouched.processingState, .ready)
        XCTAssertNotNil(untouched.processingFingerprint)
    }

    func testInsertDuplicatedPagePreservesSourceSelection() throws {
        var document = makeDocumentWithDistinctPages(count: 2)
        let sourceID = try XCTUnwrap(document.pages.first?.id)
        document.selectPage(id: sourceID)

        let duplicateID = UUID()
        let duplicatePage = ScanDraftPage(
            id: duplicateID,
            sourceType: .photos,
            originalImage: ScanDraftImageReference(relativePath: "originals/duplicate.jpg"),
            originalPixelSize: CGSize(width: 100, height: 140)
        )
        document.insertDuplicatedPage(duplicatePage, after: sourceID)

        XCTAssertEqual(document.pages.count, 3)
        XCTAssertEqual(document.pages[0].id, sourceID)
        XCTAssertEqual(document.pages[1].id, duplicateID)
        XCTAssertEqual(document.selectedPageID, sourceID)
    }

    private func makeDocumentWithDistinctPages(count: Int) -> ScanDraftDocument {
        var document = ScanDraftDocument()
        for index in 0..<count {
            var geometry = ScanPageGeometry.default
            geometry.rotation = (index * 90) % 360
            var visual = ScanVisualAdjustments.neutral
            visual.brightness = Double(index) * 0.1

            document.addPage(
                ScanDraftPage(
                    id: UUID(),
                    sourceType: index.isMultiple(of: 2) ? .camera : .photos,
                    originalImage: ScanDraftImageReference(relativePath: "originals/page-\(index).jpg"),
                    processedImage: ScanDraftImageReference(relativePath: "processed/page-\(index).jpg"),
                    thumbnailImage: ScanDraftImageReference(relativePath: "thumbnails/page-\(index).jpg"),
                    originalPixelSize: CGSize(width: 100, height: 140),
                    geometry: geometry,
                    visualAdjustments: visual,
                    processingState: .ready,
                    thumbnailState: .ready,
                    processingFingerprint: "fingerprint-\(index)"
                )
            )
        }
        return document
    }
}

@MainActor
final class ScanDraftPageManagementViewModelRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        viewModel = ScanDraftSessionViewModel(storage: storage)
    }

    func testDeletePageRemovesAssetsAndLeavesRemainingPagesUntouched() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 3)
        try await waitForProcessingToFinish()

        let pageIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        let middleID = pageIDs[1]
        let remainingIDs = [pageIDs[0], pageIDs[2]]
        let sessionDirectory = try XCTUnwrap(viewModel.sessionDirectory)
        let fingerprintBefore = try XCTUnwrap(viewModel.document?.pages[0].processingFingerprint)
        let fingerprintAfter = try XCTUnwrap(viewModel.document?.pages[2].processingFingerprint)
        viewModel.selectPage(id: middleID)

        viewModel.deletePages(ids: [middleID])

        XCTAssertEqual(viewModel.document?.pages.map(\.id), remainingIDs)
        XCTAssertEqual(viewModel.document?.selectedPageID, pageIDs[2])
        XCTAssertFalse(fileExists(relativePath: "originals/\(middleID.uuidString).jpg", sessionDirectory: sessionDirectory))
        XCTAssertFalse(fileExists(relativePath: "processed/\(middleID.uuidString).jpg", sessionDirectory: sessionDirectory))
        XCTAssertFalse(fileExists(relativePath: "thumbnails/\(middleID.uuidString).jpg", sessionDirectory: sessionDirectory))
        XCTAssertTrue(fileExists(relativePath: "originals/\(pageIDs[0].uuidString).jpg", sessionDirectory: sessionDirectory))
        XCTAssertTrue(fileExists(relativePath: "originals/\(pageIDs[2].uuidString).jpg", sessionDirectory: sessionDirectory))
        XCTAssertEqual(viewModel.document?.pages[0].processingFingerprint, fingerprintBefore)
        XCTAssertEqual(viewModel.document?.pages[1].processingFingerprint, fingerprintAfter)
    }

    func testDeleteMultipleSelectedPagesCleansFilesAndRepairsSelection() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 4)
        try await waitForProcessingToFinish()

        let pageIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        let sessionDirectory = try XCTUnwrap(viewModel.sessionDirectory)
        viewModel.enterMultiSelectionMode()
        viewModel.toggleBatchSelection(pageID: pageIDs[1])
        viewModel.toggleBatchSelection(pageID: pageIDs[2])
        viewModel.selectPage(id: pageIDs[2])

        viewModel.deletePages(ids: viewModel.pageIDsForDeletion())

        XCTAssertEqual(viewModel.document?.pages.map(\.id), [pageIDs[0], pageIDs[3]])
        XCTAssertEqual(viewModel.document?.selectedPageID, pageIDs[3])
        XCTAssertFalse(viewModel.isMultiSelectionMode)
        XCTAssertFalse(fileExists(relativePath: "originals/\(pageIDs[1].uuidString).jpg", sessionDirectory: sessionDirectory))
        XCTAssertFalse(fileExists(relativePath: "originals/\(pageIDs[2].uuidString).jpg", sessionDirectory: sessionDirectory))
    }

    func testDeleteLastPageEntersEmptyDraftState() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        try await waitForProcessingToFinish()

        let pageID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        viewModel.selectPage(id: pageID)

        viewModel.deletePages(ids: [pageID])

        XCTAssertNotNil(viewModel.document)
        XCTAssertTrue(viewModel.document?.isEmpty == true)
        XCTAssertNil(viewModel.document?.selectedPageID)
    }

    func testReorderDoesNotTriggerProcessing() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 3)
        try await waitForProcessingToFinish()

        let fingerprintsBefore = try XCTUnwrap(viewModel.document?.pages.map(\.processingFingerprint))

        viewModel.reorderPages(from: 0, to: 2)

        XCTAssertFalse(viewModel.isProcessingPages)
        XCTAssertEqual(viewModel.document?.pages.map(\.processingFingerprint), [
            fingerprintsBefore[1],
            fingerprintsBefore[2],
            fingerprintsBefore[0]
        ])
    }

    func testRotateSelectedPageReprocessesOnlyRotatedPage() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let pageIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        let firstID = pageIDs[0]
        let secondFingerprint = try XCTUnwrap(viewModel.document?.pages[1].processingFingerprint)
        viewModel.selectPage(id: firstID)

        viewModel.rotateSelectedPage()
        try await waitForProcessingToFinish()

        let rotated = try XCTUnwrap(viewModel.document?.pages.first(where: { $0.id == firstID }))
        XCTAssertEqual(rotated.geometry.rotation, 90)
        XCTAssertEqual(rotated.processingState, .ready)
        XCTAssertNotNil(rotated.processingFingerprint)
        XCTAssertNotNil(rotated.processedImage)
        XCTAssertNotNil(rotated.thumbnailImage)

        let untouched = try XCTUnwrap(viewModel.document?.pages.last)
        XCTAssertEqual(untouched.processingFingerprint, secondFingerprint)
        XCTAssertEqual(untouched.geometry.rotation, 0)
        XCTAssertEqual(viewModel.document?.selectedPageID, firstID)
    }

    func testDuplicatePageCopiesAssetsWithoutReprocessing() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        try await waitForProcessingToFinish()

        let sourceID = try XCTUnwrap(viewModel.document?.pages.first?.id)
        let sourceFingerprint = try XCTUnwrap(viewModel.document?.pages.first?.processingFingerprint)
        let sourceGeometry = try XCTUnwrap(viewModel.document?.pages.first?.geometry)
        let sessionDirectory = try XCTUnwrap(viewModel.sessionDirectory)
        viewModel.selectPage(id: sourceID)

        viewModel.duplicatePage(id: sourceID)

        XCTAssertEqual(viewModel.document?.pages.count, 2)
        let duplicate = try XCTUnwrap(viewModel.document?.pages.last)
        XCTAssertNotEqual(duplicate.id, sourceID)
        XCTAssertEqual(duplicate.geometry, sourceGeometry)
        XCTAssertEqual(duplicate.processingState, .ready)
        XCTAssertNotNil(duplicate.processingFingerprint)
        XCTAssertNotEqual(duplicate.processingFingerprint, sourceFingerprint)
        XCTAssertTrue(fileExists(relativePath: duplicate.originalImage.relativePath, sessionDirectory: sessionDirectory))
        XCTAssertTrue(fileExists(relativePath: try XCTUnwrap(duplicate.processedImage?.relativePath), sessionDirectory: sessionDirectory))
        XCTAssertFalse(viewModel.isProcessingPages)
    }

    func testAddPhotosPagesAppendsAndPreservesExistingPages() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        let existingIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        let selectedID = try XCTUnwrap(existingIDs.first)
        viewModel.selectPage(id: selectedID)

        var defaults = ScanVisualAdjustments.neutral
        defaults.mode = .enhanced
        viewModel.updateSessionDefaultVisualAdjustments(defaults)

        try viewModel.prepareSessionForAcquisition(context: .addToExistingDraft)
        await importPhotos(count: 1)

        XCTAssertEqual(viewModel.document?.pages.count, 3)
        XCTAssertEqual(viewModel.document?.pages.prefix(2).map(\.id), existingIDs)
        XCTAssertEqual(viewModel.document?.selectedPageID, selectedID)
        XCTAssertEqual(viewModel.document?.pages.last?.visualAdjustments.mode, .enhanced)
        XCTAssertEqual(viewModel.document?.pages.first?.visualAdjustments.mode, .original)
    }

    func testDeleteIgnoresInvalidPageIdentifier() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        viewModel.deletePages(ids: [UUID()])

        XCTAssertEqual(viewModel.document?.pages.count, 2)
        XCTAssertNil(viewModel.errorMessage)
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }

    private func fileExists(relativePath: String, sessionDirectory: URL) -> Bool {
        FileManager.default.fileExists(atPath: sessionDirectory.appendingPathComponent(relativePath).path)
    }

    private func waitForProcessingToFinish(timeoutNanoseconds: UInt64 = 3_000_000_000) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if viewModel.isProcessingPages == false,
               viewModel.document?.pages.allSatisfy({ $0.processingState == .ready }) == true {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for page processing")
    }
}

final class ScanDraftPageManagementStorageRegressionTests: XCTestCase {
    func testDeletePageAssetsRemovesOnlyReferencedFiles() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())

        let keepPage = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: UUID(),
            sourceType: .camera,
            sessionDirectory: sessionDirectory
        )
        let deletePage = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: UUID(),
            sourceType: .photos,
            sessionDirectory: sessionDirectory
        )

        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processedDelete = try await orchestrator.processPage(deletePage, sessionDirectory: sessionDirectory)

        storage.deletePageAssets(for: processedDelete.page, sessionDirectory: sessionDirectory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: processedDelete.page.originalImage.url(in: sessionDirectory).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: processedDelete.page.processedImage?.url(in: sessionDirectory).path ?? ""))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keepPage.originalImage.url(in: sessionDirectory).path))
    }
}
