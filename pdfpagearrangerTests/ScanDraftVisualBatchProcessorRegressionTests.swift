import XCTest
@testable import pdfpagearranger

final class ScanDraftVisualBatchProcessorRegressionTests: XCTestCase {
    func testBatchProcessorPreservesGeometryForNonSourcePages() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let processor = ScanDraftVisualBatchProcessor(storage: storage)
        let sessionDirectory = try storage.createSessionDirectory(for: UUID())

        let firstID = UUID()
        let secondID = UUID()
        var firstGeometry = ScanPageGeometry.default
        firstGeometry.rotation = 90
        var secondGeometry = ScanPageGeometry.default
        secondGeometry.rotation = 180

        let firstPage = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: firstID,
            sourceType: .camera,
            sessionDirectory: sessionDirectory
        )
        let secondPage = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: secondID,
            sourceType: .photos,
            sessionDirectory: sessionDirectory
        )

        var pageOne = firstPage
        pageOne.geometry = firstGeometry
        var pageTwo = secondPage
        pageTwo.geometry = secondGeometry

        var visual = ScanVisualAdjustments.neutral
        visual.mode = .grayscale

        let request = ScanDraftVisualBatchRequest(
            operationID: UUID(),
            draftID: UUID(),
            sourcePageID: firstID,
            sourceGeometry: firstGeometry,
            visualAdjustments: visual,
            targetPageIDs: [firstID, secondID],
            updateSessionDefaults: false
        )

        let result = try await processor.execute(
            request: request,
            pages: [pageOne, pageTwo],
            sessionDirectory: sessionDirectory,
            isCancelled: { false },
            onProgress: { _ in }
        )

        let committed = try processor.commitBatchResults(
            request: request,
            result: result,
            snapshots: [pageOne, pageTwo].map { ScanDraftPageRollbackSnapshot(page: $0) },
            sessionDirectory: sessionDirectory
        )

        let updatedSecond = try XCTUnwrap(committed.first(where: { $0.id == secondID }))
        XCTAssertEqual(updatedSecond.geometry.rotation, 180)
        XCTAssertEqual(updatedSecond.visualAdjustments.mode, .grayscale)
        XCTAssertNotEqual(updatedSecond.geometry.rotation, firstGeometry.rotation)
    }
}
