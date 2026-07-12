import Foundation

struct ScanPageProcessingResult: Sendable {
    var page: ScanDraftPage
}

/// Orchestrates the future image-processing pipeline without blocking the main actor.
///
/// Intended order:
/// 1. Normalize orientation
/// 2. Detect boundaries
/// 3. Apply crop geometry
/// 4. Apply perspective correction
/// 5. Apply rotation
/// 6. Apply visual adjustments
/// 7. Generate thumbnail
/// 8. Generate processed page image
///
/// V1 foundation runs the stage sequence and file plumbing only; filters and geometry
/// algorithms are deferred to later prompts.
actor ScanPageProcessingOrchestrator {
    typealias ProgressHandler = @Sendable (UUID, ScanProcessingStage) -> Void

    private let storage: ScanDraftSessionStorage
    private var cancelledPageIDs: Set<UUID> = []

    init(storage: ScanDraftSessionStorage = ScanDraftSessionStorage()) {
        self.storage = storage
    }

    func shouldReprocess(_ page: ScanDraftPage) -> Bool {
        page.needsProcessing
    }

    func cancelProcessing(pageID: UUID) {
        cancelledPageIDs.insert(pageID)
    }

    func cancelAll() {
        cancelledPageIDs.removeAll()
    }

    func processPage(
        _ page: ScanDraftPage,
        sessionDirectory: URL,
        onProgress: ProgressHandler? = nil
    ) async throws -> ScanPageProcessingResult {
        if ScanProcessingFingerprint.isProcessedOutputValid(for: page) {
            return ScanPageProcessingResult(page: page)
        }

        cancelledPageIDs.remove(page.id)
        var workingPage = page
        workingPage.processingState = .processing
        workingPage.processingError = nil

        let stages: [ScanProcessingStage] = [
            .normalizeOrientation,
            .detectBoundaries,
            .applyCrop,
            .applyPerspectiveCorrection,
            .applyRotation,
            .applyVisualAdjustments,
            .generateThumbnail,
            .generateProcessedImage
        ]

        do {
            for stage in stages {
                try Task.checkCancellation()
                if cancelledPageIDs.contains(page.id) {
                    throw CancellationError()
                }
                onProgress?(page.id, stage)
                try await runStage(stage, page: &workingPage, sessionDirectory: sessionDirectory)
            }

            let fingerprint = ScanProcessingFingerprint.value(for: workingPage)
            workingPage.processingFingerprint = fingerprint
            workingPage.processingState = .ready
            workingPage.processingError = nil
            return ScanPageProcessingResult(page: workingPage)
        } catch is CancellationError {
            workingPage.processingState = .pending
            throw CancellationError()
        } catch let error as ScanDraftError {
            workingPage.processingState = .failed
            workingPage.processingError = error.localizedDescription
            throw error
        } catch {
            workingPage.processingState = .failed
            workingPage.processingError = error.localizedDescription
            throw ScanDraftError.processingFailure(stage: .generateProcessedImage)
        }
    }

    func processPages(
        _ pages: [ScanDraftPage],
        sessionDirectory: URL,
        onProgress: ProgressHandler? = nil,
        onPageCompleted: @Sendable (ScanDraftPage) -> Void = { _ in }
    ) async throws -> [ScanDraftPage] {
        var results: [ScanDraftPage] = []
        results.reserveCapacity(pages.count)

        for page in pages {
            if ScanProcessingFingerprint.isProcessedOutputValid(for: page) {
                results.append(page)
                onPageCompleted(page)
                continue
            }

            let result = try await processPage(page, sessionDirectory: sessionDirectory, onProgress: onProgress)
            results.append(result.page)
            onPageCompleted(result.page)
        }

        return results
    }

    // MARK: - Deferred stage implementations

    private func runStage(
        _ stage: ScanProcessingStage,
        page: inout ScanDraftPage,
        sessionDirectory: URL
    ) async throws {
        switch stage {
        case .normalizeOrientation,
             .detectBoundaries,
             .applyCrop,
             .applyPerspectiveCorrection,
             .applyRotation,
             .applyVisualAdjustments:
            // Algorithms deferred; state is carried on `ScanDraftPage` for future stages.
            return

        case .generateThumbnail:
            try await generateThumbnail(for: &page, sessionDirectory: sessionDirectory)

        case .generateProcessedImage:
            try await generateProcessedImage(for: &page, sessionDirectory: sessionDirectory)
        }
    }

    private func generateProcessedImage(
        for page: inout ScanDraftPage,
        sessionDirectory: URL
    ) async throws {
        let outputData = try await generateGeometryProcessedData(for: page, sessionDirectory: sessionDirectory)
        let processedReference = try storage.replaceProcessedImage(
            data: outputData,
            pageID: page.id,
            sessionDirectory: sessionDirectory,
            previousReference: page.processedImage
        )
        page.processedImage = processedReference
    }

    private func generateGeometryProcessedData(
        for page: ScanDraftPage,
        sessionDirectory: URL
    ) async throws -> Data {
        let originalData = try storage.loadImageData(at: page.originalImage, sessionDirectory: sessionDirectory)
        let needsProcessing = page.geometry.perspectiveCorrectionEnabled
            || page.geometry.rotation != 0
            || page.geometry.effectiveCorners != nil

        guard needsProcessing else {
            return originalData
        }

        return try await Task.detached(priority: .userInitiated) {
            try ScanPerspectiveCorrectionEngine.process(
                sourceData: originalData,
                geometry: page.geometry,
                pixelSize: page.originalPixelSize
            ).data
        }.value
    }

    private func generateThumbnail(
        for page: inout ScanDraftPage,
        sessionDirectory: URL
    ) async throws {
        page.thumbnailState = .generating
        let sourceReference = page.processedImage ?? page.originalImage
        let sourceData = try storage.loadImageData(at: sourceReference, sessionDirectory: sessionDirectory)
        let thumbnailReference = try storage.writeThumbnailImage(
            data: sourceData,
            pageID: page.id,
            sessionDirectory: sessionDirectory
        )
        page.thumbnailImage = thumbnailReference
        page.thumbnailState = .ready
    }
}
