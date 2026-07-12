import XCTest
@testable import pdfpagearranger

final class ScanDraftPreviewImageLoaderRegressionTests: XCTestCase {
    func testPreviewReferencePrefersValidProcessedImage() {
        let loader = ScanDraftPreviewImageLoader()
        var page = makePage()
        page.processedImage = ScanDraftImageReference(relativePath: "processed/page.jpg")
        page.processingState = .ready
        page.processingFingerprint = ScanProcessingFingerprint.value(for: page)

        XCTAssertEqual(loader.previewReference(for: page).relativePath, "processed/page.jpg")
    }

    func testPreviewReferenceFallsBackToOriginalWhenProcessedInvalid() {
        let loader = ScanDraftPreviewImageLoader()
        let page = makePage()

        XCTAssertEqual(loader.previewReference(for: page).relativePath, "originals/page.jpg")
    }

    func testThumbnailReferencePrefersReadyThumbnail() {
        let loader = ScanDraftPreviewImageLoader()
        var page = makePage()
        page.thumbnailImage = ScanDraftImageReference(relativePath: "thumbnails/page.jpg")
        page.thumbnailState = .ready

        XCTAssertEqual(loader.thumbnailReference(for: page).relativePath, "thumbnails/page.jpg")
    }

    func testLoadImageReadsFileBackedReference() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let loader = ScanDraftPreviewImageLoader(storage: storage)
        let documentID = UUID()
        let sessionDirectory = try storage.createSessionDirectory(for: documentID)
        let pageID = UUID()
        let page = try storage.importOriginalImage(
            data: ScanDraftTestFactory.makeTestImageData(),
            pageID: pageID,
            sourceType: .photos,
            sessionDirectory: sessionDirectory
        )

        let image = try await loader.loadImage(
            reference: page.originalImage,
            sessionDirectory: sessionDirectory,
            maxPixelDimension: 200
        )

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    private func makePage() -> ScanDraftPage {
        ScanDraftPage(
            id: UUID(),
            sourceType: .camera,
            originalImage: ScanDraftImageReference(relativePath: "originals/page.jpg"),
            originalPixelSize: CGSize(width: 200, height: 280)
        )
    }
}
