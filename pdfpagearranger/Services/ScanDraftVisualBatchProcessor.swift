import Foundation

struct ScanDraftPageRollbackSnapshot: Equatable, Sendable {
    let page: ScanDraftPage
}

struct ScanDraftVisualBatchRequest: Sendable {
    let operationID: UUID
    let draftID: UUID
    let sourcePageID: UUID
    let sourceGeometry: ScanPageGeometry
    let visualAdjustments: ScanVisualAdjustments
    let targetPageIDs: [UUID]
    let updateSessionDefaults: Bool
}

struct ScanDraftVisualBatchResult: Sendable {
    let updatedPages: [ScanDraftPage]
    let sessionDefaultVisualAdjustments: ScanVisualAdjustments?
}

/// Sequential visual-batch processor with journaled rollback on failure or cancellation.
struct ScanDraftVisualBatchProcessor: Sendable {
    let storage: ScanDraftSessionStorage
    let geometryProcessor: ScanDraftPageGeometryProcessor

    init(
        storage: ScanDraftSessionStorage = ScanDraftSessionStorage(),
        geometryProcessor: ScanDraftPageGeometryProcessor? = nil
    ) {
        self.storage = storage
        self.geometryProcessor = geometryProcessor ?? ScanDraftPageGeometryProcessor(storage: storage)
    }

    func execute(
        request: ScanDraftVisualBatchRequest,
        pages: [ScanDraftPage],
        sessionDirectory: URL,
        isCancelled: @Sendable @escaping () -> Bool,
        onProgress: @Sendable @escaping (ScanDraftVisualBatchProgress) -> Void
    ) async throws -> ScanDraftVisualBatchResult {
        let snapshots = pages
            .filter { request.targetPageIDs.contains($0.id) }
            .map { ScanDraftPageRollbackSnapshot(page: $0) }

        var updatedByID: [UUID: ScanDraftPage] = [:]
        let total = request.targetPageIDs.count
        var completed = 0

        onProgress(
            ScanDraftVisualBatchProgress(
                completed: 0,
                total: total,
                currentPageID: request.targetPageIDs.first,
                currentPageNumber: 1,
                isCancelling: false
            )
        )

        do {
            for (index, pageID) in request.targetPageIDs.enumerated() {
                try Task.checkCancellation()
                if isCancelled() {
                    throw CancellationError()
                }

                guard let originalPage = pages.first(where: { $0.id == pageID }) else {
                    completed += 1
                    continue
                }

                onProgress(
                    ScanDraftVisualBatchProgress(
                        completed: completed,
                        total: total,
                        currentPageID: pageID,
                        currentPageNumber: index + 1,
                        isCancelling: false
                    )
                )

                let updatedPage = try await processTargetPage(
                    originalPage: originalPage,
                    request: request,
                    sessionDirectory: sessionDirectory,
                    operationID: request.operationID
                )

                updatedByID[pageID] = updatedPage
                completed += 1

                onProgress(
                    ScanDraftVisualBatchProgress(
                        completed: completed,
                        total: total,
                        currentPageID: pageID,
                        currentPageNumber: index + 1,
                        isCancelling: false
                    )
                )
            }

            let ordered = request.targetPageIDs.compactMap { updatedByID[$0] }
            let sessionDefaults = request.updateSessionDefaults
                ? request.visualAdjustments.normalizedForProcessing()
                : nil
            return ScanDraftVisualBatchResult(
                updatedPages: ordered,
                sessionDefaultVisualAdjustments: sessionDefaults
            )
        } catch {
            try storage.deleteBatchStagingFiles(
                operationID: request.operationID,
                sessionDirectory: sessionDirectory
            )
            throw error
        }
    }


    private func processTargetPage(
        originalPage: ScanDraftPage,
        request: ScanDraftVisualBatchRequest,
        sessionDirectory: URL,
        operationID: UUID
    ) async throws -> ScanDraftPage {
        let visualAdjustments = request.visualAdjustments.normalizedForProcessing()
        let isSourcePage = originalPage.id == request.sourcePageID

        var candidate = originalPage
        candidate.visualAdjustments = visualAdjustments

        if isSourcePage {
            candidate.geometry = request.sourceGeometry
        }

        if ScanProcessingFingerprint.isProcessedOutputValid(for: candidate),
           candidate.processingState == .ready,
           candidate.processedImage != nil {
            return candidate
        }

        let geometry = isSourcePage ? request.sourceGeometry : originalPage.geometry

        let processedData = try await Task.detached(priority: .userInitiated) {
            let originalData = try storage.loadImageData(
                at: originalPage.originalImage,
                sessionDirectory: sessionDirectory
            )
            return try ScanDraftPageImageProcessor.process(
                sourceData: originalData,
                geometry: geometry,
                visualAdjustments: visualAdjustments,
                pixelSize: originalPage.originalPixelSize,
                maxOutputPixelDimension: ScanDraftPageImageProcessor.fullResolutionMaxDimension
            )
        }.value

        let processedReference = try storage.writeBatchStagingProcessedImage(
            data: processedData.data,
            pageID: originalPage.id,
            operationID: operationID,
            sessionDirectory: sessionDirectory
        )

        let thumbnailReference = try storage.writeBatchStagingThumbnailImage(
            data: processedData.data,
            pageID: originalPage.id,
            operationID: operationID,
            sessionDirectory: sessionDirectory
        )

        var updatedPage = candidate
        updatedPage.geometry = geometry
        updatedPage.processingState = .ready
        updatedPage.processingError = nil
        updatedPage.processingFingerprint = ScanProcessingFingerprint.value(for: updatedPage)
        updatedPage.processedImage = processedReference
        updatedPage.thumbnailImage = thumbnailReference
        updatedPage.thumbnailState = .ready

        return updatedPage
    }

    func commitBatchResults(
        request: ScanDraftVisualBatchRequest,
        result: ScanDraftVisualBatchResult,
        snapshots: [ScanDraftPageRollbackSnapshot],
        sessionDirectory: URL
    ) throws -> [ScanDraftPage] {
        var committedPages: [ScanDraftPage] = []

        for var updatedPage in result.updatedPages {
            guard let snapshot = snapshots.first(where: { $0.page.id == updatedPage.id }) else {
                committedPages.append(updatedPage)
                continue
            }

            if let stagedProcessed = updatedPage.processedImage,
               stagedProcessed.relativePath.contains(".batch/") {
                let stagedProcessedData = try storage.loadImageData(
                    at: stagedProcessed,
                    sessionDirectory: sessionDirectory
                )
                let finalProcessed = try storage.replaceProcessedImage(
                    data: stagedProcessedData,
                    pageID: updatedPage.id,
                    sessionDirectory: sessionDirectory,
                    previousReference: snapshot.page.processedImage
                )
                updatedPage.processedImage = finalProcessed

                let stagedThumbnailData = stagedProcessedData
                let finalThumbnail = try storage.writeThumbnailImage(
                    data: stagedThumbnailData,
                    pageID: updatedPage.id,
                    sessionDirectory: sessionDirectory
                )
                updatedPage.thumbnailImage = finalThumbnail
                updatedPage.thumbnailState = .ready
            }

            committedPages.append(updatedPage)
        }

        try storage.deleteBatchStagingFiles(
            operationID: request.operationID,
            sessionDirectory: sessionDirectory
        )

        return committedPages
    }
}
