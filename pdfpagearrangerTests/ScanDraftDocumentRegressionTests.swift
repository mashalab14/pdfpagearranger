import XCTest
@testable import pdfpagearranger

final class ScanDraftDocumentRegressionTests: XCTestCase {
    func testAddMultiplePagesPreservesOrder() throws {
        var document = ScanDraftDocument()
        let firstID = UUID()
        let secondID = UUID()

        document.addPage(
            ScanDraftPage(
                id: firstID,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/a.jpg"),
                originalPixelSize: CGSize(width: 100, height: 100)
            )
        )
        document.addPage(
            ScanDraftPage(
                id: secondID,
                sourceType: .photos,
                originalImage: ScanDraftImageReference(relativePath: "originals/b.jpg"),
                originalPixelSize: CGSize(width: 100, height: 100)
            )
        )

        XCTAssertEqual(document.pages.map(\.id), [firstID, secondID])
        XCTAssertEqual(document.selectedPageID, firstID)
    }

    func testRemovePageUpdatesCurrentSelection() {
        var document = ScanDraftDocument()
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        document.addPages([
            ScanDraftPage(
                id: firstID,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/1.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            ),
            ScanDraftPage(
                id: secondID,
                sourceType: .photos,
                originalImage: ScanDraftImageReference(relativePath: "originals/2.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            ),
            ScanDraftPage(
                id: thirdID,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/3.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            )
        ])
        document.selectPage(id: secondID)

        XCTAssertTrue(document.removePage(id: secondID))
        XCTAssertEqual(document.selectedPageID, thirdID)
        XCTAssertEqual(document.pages.map(\.id), [firstID, thirdID])
    }

    func testReorderPagesChangesOrder() {
        var document = ScanDraftDocument()
        let ids = (0..<3).map { _ in UUID() }
        for id in ids {
            document.addPage(
                ScanDraftPage(
                    id: id,
                    sourceType: .camera,
                    originalImage: ScanDraftImageReference(relativePath: "originals/\(id.uuidString).jpg"),
                    originalPixelSize: CGSize(width: 10, height: 10)
                )
            )
        }

        document.reorderPages(from: 0, to: 2)
        XCTAssertEqual(document.pages.map(\.id), [ids[1], ids[2], ids[0]])
    }

    func testPageIdentityRemainsStableAcrossUpdates() {
        var document = ScanDraftDocument()
        let pageID = UUID()
        document.addPage(
            ScanDraftPage(
                id: pageID,
                sourceType: .photos,
                originalImage: ScanDraftImageReference(relativePath: "originals/stable.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            )
        )

        document.updatePage(id: pageID) { page in
            page.visualAdjustments.mode = .enhanced
        }

        XCTAssertEqual(document.pages.first?.id, pageID)
    }

    func testApplyVisualAdjustmentsToSelectedPagesOnly() throws {
        var document = ScanDraftDocument()
        let firstID = UUID()
        let secondID = UUID()
        document.addPages([
            ScanDraftPage(
                id: firstID,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/1.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            ),
            ScanDraftPage(
                id: secondID,
                sourceType: .photos,
                originalImage: ScanDraftImageReference(relativePath: "originals/2.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            )
        ])

        var selectedAdjustments = ScanVisualAdjustments.neutral
        selectedAdjustments.mode = .grayscale
        selectedAdjustments.brightness = 0.2

        document.applyVisualAdjustments(selectedAdjustments, toPageIDs: [secondID])

        XCTAssertEqual(document.pages.first?.visualAdjustments.mode, .original)
        XCTAssertEqual(document.pages.last?.visualAdjustments.mode, .grayscale)
        let adjustedBrightness = try XCTUnwrap(document.pages.last?.visualAdjustments.brightness)
        XCTAssertEqual(adjustedBrightness, 0.2, accuracy: 0.001)
    }

    func testApplyVisualAdjustmentsToAllPages() {
        var document = ScanDraftDocument()
        document.addPages([
            ScanDraftPage(
                id: UUID(),
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/1.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            ),
            ScanDraftPage(
                id: UUID(),
                sourceType: .photos,
                originalImage: ScanDraftImageReference(relativePath: "originals/2.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10)
            )
        ])

        var adjustments = ScanVisualAdjustments.neutral
        adjustments.mode = .blackAndWhite
        adjustments.contrast = 0.4
        document.applyVisualAdjustmentsToAll(adjustments)

        XCTAssertTrue(document.pages.allSatisfy { $0.visualAdjustments.mode == .blackAndWhite })
        XCTAssertEqual(document.sessionDefaultVisualAdjustments.mode, .blackAndWhite)
    }

    func testGeometryRemainsPageSpecificWhenAdjustmentsAreCopied() {
        var document = ScanDraftDocument()
        let firstID = UUID()
        let secondID = UUID()

        var firstGeometry = ScanPageGeometry.default
        firstGeometry.rotation = 90
        firstGeometry.userAdjustedCorners = [
            ScanNormalizedPoint(x: 0.1, y: 0.1),
            ScanNormalizedPoint(x: 0.9, y: 0.1),
            ScanNormalizedPoint(x: 0.9, y: 0.9),
            ScanNormalizedPoint(x: 0.1, y: 0.9)
        ]

        var secondGeometry = ScanPageGeometry.default
        secondGeometry.rotation = 180

        document.addPage(
            ScanDraftPage(
                id: firstID,
                sourceType: .camera,
                originalImage: ScanDraftImageReference(relativePath: "originals/1.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10),
                geometry: firstGeometry
            )
        )
        document.addPage(
            ScanDraftPage(
                id: secondID,
                sourceType: .photos,
                originalImage: ScanDraftImageReference(relativePath: "originals/2.jpg"),
                originalPixelSize: CGSize(width: 10, height: 10),
                geometry: secondGeometry
            )
        )

        var sharedAdjustments = ScanVisualAdjustments.neutral
        sharedAdjustments.mode = .enhanced
        document.applyVisualAdjustmentsToAll(sharedAdjustments)

        XCTAssertEqual(document.pages.first?.geometry.rotation, 90)
        XCTAssertEqual(document.pages.last?.geometry.rotation, 180)
        XCTAssertEqual(document.pages.first?.geometry.userAdjustedCorners?.count, 4)
    }

    @MainActor
    func testDiscardDraftSessionDeletesTemporaryFiles() throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let viewModel = ScanDraftSessionViewModel(storage: storage)
        try viewModel.beginNewDocumentFlow()

        let documentID = try XCTUnwrap(viewModel.document?.id)
        let sessionDirectory = storage.sessionDirectory(for: documentID)
        try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: UUID(),
            sourceType: .camera,
            sessionDirectory: sessionDirectory
        )

        XCTAssertTrue(storage.sessionExists(for: documentID))

        viewModel.discardDraftSession()

        XCTAssertNil(viewModel.document)
        XCTAssertFalse(storage.sessionExists(for: documentID))
    }
}
