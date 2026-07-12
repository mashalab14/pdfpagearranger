import Foundation

struct ScanPageAdjustmentSession: Equatable, Sendable {
    let draftID: UUID
    let pageID: UUID
    let pageNumber: Int
    let totalPages: Int
    let sourceType: ScanPageSource
    var workingGeometry: ScanPageGeometry
    let committedGeometry: ScanPageGeometry
    var workingVisualAdjustments: ScanVisualAdjustments
    let committedVisualAdjustments: ScanVisualAdjustments
}

struct ScanDraftPageGeometryProcessor: Sendable {
    let storage: ScanDraftSessionStorage

    init(storage: ScanDraftSessionStorage = ScanDraftSessionStorage()) {
        self.storage = storage
    }

    func applyGeometry(
        to page: ScanDraftPage,
        geometry: ScanPageGeometry,
        sessionDirectory: URL
    ) async throws -> ScanDraftPage {
        try await applyAdjustment(
            to: page,
            geometry: geometry,
            visualAdjustments: page.visualAdjustments,
            sessionDirectory: sessionDirectory
        )
    }

    func applyAdjustment(
        to page: ScanDraftPage,
        geometry: ScanPageGeometry,
        visualAdjustments: ScanVisualAdjustments,
        sessionDirectory: URL
    ) async throws -> ScanDraftPage {
        guard case .success(let validatedCorners) = ScanPageGeometryEngine.validateCorners(
            geometry.effectiveCorners ?? ScanPageGeometryEngine.fullBoundsCorners()
        ) else {
            throw ScanDraftError.invalidPageGeometry
        }

        var committedGeometry = geometry
        committedGeometry.userAdjustedCorners = validatedCorners
        committedGeometry.perspectiveCorrectionEnabled = geometry.perspectiveCorrectionEnabled

        let committedVisualAdjustments = visualAdjustments.normalizedForProcessing()
        let originalData = try storage.loadImageData(at: page.originalImage, sessionDirectory: sessionDirectory)

        let processed = try await Task.detached(priority: .userInitiated) {
            try ScanDraftPageImageProcessor.process(
                sourceData: originalData,
                geometry: committedGeometry,
                visualAdjustments: committedVisualAdjustments,
                pixelSize: page.originalPixelSize,
                maxOutputPixelDimension: ScanDraftPageImageProcessor.fullResolutionMaxDimension
            )
        }.value

        let previousProcessed = page.processedImage
        let processedReference = try storage.replaceProcessedImage(
            data: processed.data,
            pageID: page.id,
            sessionDirectory: sessionDirectory,
            previousReference: previousProcessed
        )

        var updatedPage = page
        updatedPage.geometry = committedGeometry
        updatedPage.visualAdjustments = committedVisualAdjustments
        updatedPage.processedImage = processedReference
        updatedPage.processingState = .ready
        updatedPage.processingError = nil
        updatedPage.processingFingerprint = ScanProcessingFingerprint.value(for: updatedPage)

        let thumbnailReference = try storage.writeThumbnailImage(
            data: processed.data,
            pageID: page.id,
            sessionDirectory: sessionDirectory
        )
        updatedPage.thumbnailImage = thumbnailReference
        updatedPage.thumbnailState = .ready

        return updatedPage
    }
}
