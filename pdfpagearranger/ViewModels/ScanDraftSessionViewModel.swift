import Foundation
import PhotosUI
import SwiftUI
import VisionKit

@Observable
@MainActor
final class ScanDraftSessionViewModel {
    private(set) var document: ScanDraftDocument?
    var navigationPath: [ScanDraftRoute] = []
    private(set) var isProcessingPages = false
    private(set) var isGeneratingPDF = false
    private(set) var isImportingCameraScan = false
    private(set) var isImportingPhotos = false
    private(set) var photosImportProgress: ScanPhotosImportProgress?
    private(set) var photosSelectionHandled = false
    private(set) var adjustmentSession: ScanPageAdjustmentSession?
    private(set) var isApplyingGeometry = false
    private(set) var isDetectingEdges = false
    private(set) var isGeneratingVisualPreview = false
    private(set) var visualPreviewImage: UIImage?
    private(set) var isMultiSelectionMode = false
    private(set) var batchSelectionPageIDs: Set<UUID> = []
    private(set) var batchProgress: ScanDraftVisualBatchProgress = .idle
    private(set) var isBatchProcessing = false
    private(set) var pdfGenerationProgress: ScanDraftPDFGenerationProgress = .idle
    var adjustmentSection: ScanPageAdjustmentSection = .appearance
    var isDocumentScannerPresented = false
    var errorMessage: String?

    private let storage: ScanDraftSessionStorage
    private let processingOrchestrator: ScanPageProcessingOrchestrator
    private let pdfGenerator: any ScanDraftPDFGenerating
    private let editorHandoff: ScanEditorHandoffService
    private let cameraScanImporter: ScanCameraScanImporter
    private let photosSelectionImporter: ScanPhotosSelectionImporter
    private let geometryProcessor: ScanDraftPageGeometryProcessor
    private let visualBatchProcessor: ScanDraftVisualBatchProcessor
    private let edgeDetector: any ScanDocumentEdgeDetecting
    private let permissionChecker: any ScanCameraPermissionChecking
    private let scannerAvailability: any ScanDocumentScannerAvailabilityChecking
    private var processingTask: Task<Void, Never>?
    private var photosImportTask: Task<Void, Never>?
    private var acquisitionImportContext: ScanAcquisitionImportContext = .newDocument
    private var preImportPageIDs: Set<UUID> = []
    private var emptySessionCreatedForImport = false
    private var cameraScanCompletionHandled = false
    private var photosImportOperationID: UUID?
    private var photosImportCancellationFlag: ScanImportCancellationFlag?
    private var geometryApplyOperationID: UUID?
    private var edgeDetectionOperationID: UUID?
    private var visualPreviewOperationID: UUID?
    private var geometryApplyTask: Task<Void, Never>?
    private var visualPreviewTask: Task<Void, Never>?
    private var batchOperationID: UUID?
    private var batchCancellationFlag: ScanImportCancellationFlag?
    private var batchTask: Task<Void, Never>?
    private var pdfGenerationTask: Task<Void, Never>?

    init(
        storage: ScanDraftSessionStorage = ScanDraftSessionStorage(),
        processingOrchestrator: ScanPageProcessingOrchestrator? = nil,
        pdfGenerator: (any ScanDraftPDFGenerating)? = nil,
        editorHandoff: ScanEditorHandoffService? = nil,
        cameraScanImporter: ScanCameraScanImporter? = nil,
        photosSelectionImporter: ScanPhotosSelectionImporter? = nil,
        geometryProcessor: ScanDraftPageGeometryProcessor? = nil,
        visualBatchProcessor: ScanDraftVisualBatchProcessor? = nil,
        edgeDetector: (any ScanDocumentEdgeDetecting)? = nil,
        permissionChecker: (any ScanCameraPermissionChecking)? = nil,
        scannerAvailability: (any ScanDocumentScannerAvailabilityChecking)? = nil
    ) {
        self.storage = storage
        let orchestrator = processingOrchestrator ?? ScanPageProcessingOrchestrator(storage: storage)
        self.processingOrchestrator = orchestrator
        self.pdfGenerator = pdfGenerator ?? ScanDraftPDFGenerator(
            storage: storage,
            processingOrchestrator: orchestrator
        )
        self.editorHandoff = editorHandoff ?? ScanEditorHandoffService()
        self.cameraScanImporter = cameraScanImporter ?? ScanCameraScanImporter(storage: storage)
        self.photosSelectionImporter = photosSelectionImporter ?? ScanPhotosSelectionImporter(storage: storage)
        self.geometryProcessor = geometryProcessor ?? ScanDraftPageGeometryProcessor(storage: storage)
        self.visualBatchProcessor = visualBatchProcessor ?? ScanDraftVisualBatchProcessor(storage: storage)
        self.edgeDetector = edgeDetector ?? VisionScanDocumentEdgeDetector()
        self.permissionChecker = permissionChecker ?? SystemScanCameraPermissionChecker()
        self.scannerAvailability = scannerAvailability ?? SystemScanDocumentScannerAvailabilityChecker()
    }

    var hasActiveDraft: Bool {
        guard let document else { return false }
        return !document.isEmpty
    }

    var sessionDirectory: URL? {
        guard let document else { return nil }
        return storage.sessionDirectory(for: document.id)
    }

    // MARK: - Session lifecycle

    func beginNewDocumentFlow() throws {
        let draft = ScanDraftDocument()
        try storage.createSessionDirectory(for: draft.id)
        document = draft
        navigationPath = [.sourceSelection]
        errorMessage = nil
    }

    func discardDraftSession() {
        _ = discardDraftSessionWithCleanup()
    }

    @discardableResult
    func discardDraftSessionWithCleanup() -> Bool {
        processingTask?.cancel()
        processingTask = nil
        cancelPhotosImport()

        if let documentID = document?.id {
            do {
                try storage.deleteSession(for: documentID)
            } catch {
                errorMessage = ScanDraftError.draftCleanupFailure.localizedDescription
                return false
            }
        }

        document = nil
        navigationPath = []
        isProcessingPages = false
        isGeneratingPDF = false
        isImportingCameraScan = false
        isImportingPhotos = false
        photosImportProgress = nil
        photosSelectionHandled = false
        isDocumentScannerPresented = false
        errorMessage = nil
        preImportPageIDs = []
        emptySessionCreatedForImport = false
        cameraScanCompletionHandled = false
        photosImportOperationID = nil
        photosImportCancellationFlag = nil
        adjustmentSession = nil
        isApplyingGeometry = false
        isDetectingEdges = false
        geometryApplyOperationID = nil
        edgeDetectionOperationID = nil
        visualPreviewOperationID = nil
        geometryApplyTask?.cancel()
        geometryApplyTask = nil
        visualPreviewTask?.cancel()
        visualPreviewTask = nil
        batchTask?.cancel()
        batchTask = nil
        batchOperationID = nil
        batchCancellationFlag = nil
        batchProgress = .idle
        isBatchProcessing = false
        pdfGenerationTask?.cancel()
        pdfGenerationTask = nil
        pdfGenerationProgress = .idle
        isGeneratingPDF = false
        isMultiSelectionMode = false
        batchSelectionPageIDs = []
        visualPreviewImage = nil
        adjustmentSection = .appearance
        return true
    }

    func closeDraftIntent() -> ScanDraftCloseIntent {
        guard let document else { return .dismissImmediately }
        if document.isEmpty { return .dismissImmediately }
        if document.hasUnsavedChanges { return .confirmDiscard }
        return .dismissImmediately
    }

    func repairSelectionIfNeeded() {
        guard var draft = document else { return }
        draft.repairSelectionIfNeeded()
        document = draft
    }

    func pageNumber(for pageID: UUID) -> Int? {
        guard let document else { return nil }
        guard let index = document.pages.firstIndex(where: { $0.id == pageID }) else { return nil }
        return index + 1
    }

    func openAdjustmentForSelectedPage() {
        repairSelectionIfNeeded()
        guard let pageID = document?.selectedPageID else {
            errorMessage = ScanDraftError.emptyDraft.localizedDescription
            return
        }
        Task {
            await preparePageAdjustment(pageID: pageID)
            navigateToPageAdjustment(pageID: pageID)
        }
    }

    func preparePageAdjustment(pageID: UUID) async {
        guard let draft = document, let sessionDirectory = sessionDirectory else { return }
        guard let page = draft.pages.first(where: { $0.id == pageID }) else { return }

        let pageNumber = pageNumber(for: pageID) ?? 1
        var workingGeometry = page.geometry

        if page.sourceType == .camera, workingGeometry.effectiveCorners == nil {
            workingGeometry.detectedCorners = ScanPageGeometryEngine.fullBoundsCorners()
            workingGeometry.perspectiveCorrectionEnabled = false
        }

        adjustmentSession = ScanPageAdjustmentSession(
            draftID: draft.id,
            pageID: page.id,
            pageNumber: pageNumber,
            totalPages: draft.pages.count,
            sourceType: page.sourceType,
            workingGeometry: workingGeometry,
            committedGeometry: page.geometry,
            workingVisualAdjustments: page.visualAdjustments,
            committedVisualAdjustments: page.visualAdjustments
        )
        visualPreviewImage = nil

        if page.sourceType == .photos,
           page.geometry.userAdjustedCorners == nil,
           page.geometry.detectedCorners == nil {
            await redetectDocumentEdges()
        } else if adjustmentSession?.workingGeometry.effectiveCorners == nil {
            guard var session = adjustmentSession else { return }
            session.workingGeometry.detectedCorners = ScanPageGeometryEngine.fullBoundsCorners()
            session.workingGeometry.perspectiveCorrectionEnabled = page.sourceType == .photos
            adjustmentSession = session
        }

        scheduleVisualPreviewUpdate()
    }

    func updateAdjustmentWorkingGeometry(_ geometry: ScanPageGeometry) {
        guard var session = adjustmentSession else { return }
        session.workingGeometry = geometry
        adjustmentSession = session
        scheduleVisualPreviewUpdate()
    }

    func updateAdjustmentWorkingVisualAdjustments(_ adjustments: ScanVisualAdjustments) {
        guard var session = adjustmentSession else { return }
        session.workingVisualAdjustments = adjustments.normalizedForProcessing()
        adjustmentSession = session
        scheduleVisualPreviewUpdate()
    }

    func resetAdjustmentVisualAdjustments() {
        guard var session = adjustmentSession else { return }
        session.workingVisualAdjustments = .neutral
        adjustmentSession = session
        scheduleVisualPreviewUpdate()
    }

    func scheduleVisualPreviewUpdate() {
        visualPreviewTask?.cancel()
        visualPreviewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            await self?.generateVisualPreview()
        }
    }

    func generateVisualPreview() async {
        guard let session = adjustmentSession else { return }
        guard let sessionDirectory = sessionDirectory else { return }
        guard let page = document?.pages.first(where: { $0.id == session.pageID }) else { return }

        let operationID = UUID()
        visualPreviewOperationID = operationID
        isGeneratingVisualPreview = true

        let geometry = session.workingGeometry
        let visualAdjustments = session.workingVisualAdjustments.normalizedForProcessing()
        let pageID = session.pageID
        let draftID = session.draftID

        do {
            let originalData = try storage.loadImageData(at: page.originalImage, sessionDirectory: sessionDirectory)
            let previewData = try await Task.detached(priority: .userInitiated) {
                try ScanDraftPageImageProcessor.process(
                    sourceData: originalData,
                    geometry: geometry,
                    visualAdjustments: visualAdjustments,
                    pixelSize: page.originalPixelSize,
                    maxOutputPixelDimension: ScanDraftPageImageProcessor.previewMaxDimension
                ).data
            }.value

            guard visualPreviewOperationID == operationID,
                  adjustmentSession?.pageID == pageID,
                  document?.id == draftID,
                  let image = UIImage(data: previewData) else {
                return
            }

            visualPreviewImage = image
        } catch {
            guard visualPreviewOperationID == operationID else { return }
        }

        if visualPreviewOperationID == operationID {
            isGeneratingVisualPreview = false
        }
    }

    func rotateAdjustmentGeometryClockwise() {
        guard var session = adjustmentSession else { return }
        session.workingGeometry = session.workingGeometry.rotated()
        adjustmentSession = session
        scheduleVisualPreviewUpdate()
    }

    func resetAdjustmentGeometry() {
        guard var session = adjustmentSession else { return }
        var geometry = session.committedGeometry
        if geometry.effectiveCorners == nil {
            geometry.detectedCorners = ScanPageGeometryEngine.fullBoundsCorners()
            geometry.perspectiveCorrectionEnabled = session.sourceType == .photos
        }
        session.workingGeometry = geometry
        adjustmentSession = session
        scheduleVisualPreviewUpdate()
    }

    func redetectDocumentEdges() async {
        guard var session = adjustmentSession else { return }
        guard let sessionDirectory = sessionDirectory else { return }
        guard let page = document?.pages.first(where: { $0.id == session.pageID }) else { return }

        let operationID = UUID()
        edgeDetectionOperationID = operationID
        isDetectingEdges = true
        defer {
            if edgeDetectionOperationID == operationID {
                isDetectingEdges = false
            }
        }

        do {
            let imageData = try storage.loadImageData(at: page.originalImage, sessionDirectory: sessionDirectory)
            guard let detection = try await edgeDetector.detectDocument(in: imageData) else {
                session.workingGeometry.detectedCorners = ScanPageGeometryEngine.fullBoundsCorners()
                session.workingGeometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners()
                session.workingGeometry.perspectiveCorrectionEnabled = session.sourceType == .photos
                adjustmentSession = session
                scheduleVisualPreviewUpdate()
                return
            }

            guard edgeDetectionOperationID == operationID else { return }
            session.workingGeometry.detectedCorners = detection.corners
            session.workingGeometry.userAdjustedCorners = detection.corners
            session.workingGeometry.perspectiveCorrectionEnabled = true
            adjustmentSession = session
            scheduleVisualPreviewUpdate()
        } catch {
            guard edgeDetectionOperationID == operationID else { return }
            session.workingGeometry.detectedCorners = ScanPageGeometryEngine.fullBoundsCorners()
            session.workingGeometry.userAdjustedCorners = ScanPageGeometryEngine.fullBoundsCorners()
            session.workingGeometry.perspectiveCorrectionEnabled = session.sourceType == .photos
            adjustmentSession = session
            scheduleVisualPreviewUpdate()
        }
    }

    func cancelPageAdjustment() {
        geometryApplyTask?.cancel()
        visualPreviewTask?.cancel()
        geometryApplyOperationID = nil
        edgeDetectionOperationID = nil
        visualPreviewOperationID = nil
        adjustmentSession = nil
        visualPreviewImage = nil
        isApplyingGeometry = false
        isDetectingEdges = false
        isGeneratingVisualPreview = false
        adjustmentSection = .appearance
        navigateToDraftReview()
    }

    func applyPageAdjustment(scope: ScanVisualBatchApplyScope) async -> Bool {
        guard !isApplyingGeometry, !isBatchProcessing else { return false }
        guard let session = adjustmentSession else { return false }
        guard let draft = document, let sessionDirectory = sessionDirectory else { return false }

        if scope == .selectedPages, batchSelectionPageIDs.isEmpty {
            errorMessage = ScanDraftError.emptyBatchSelection.localizedDescription
            return false
        }

        let targetPageIDs = resolvedTargetPageIDs(for: scope, sourcePageID: session.pageID)
        guard !targetPageIDs.isEmpty else {
            errorMessage = ScanDraftError.emptyBatchSelection.localizedDescription
            return false
        }

        if scope == .thisPage {
            return await applySinglePageAdjustment(session: session, sessionDirectory: sessionDirectory)
        }

        return await applyBatchVisualAdjustment(
            session: session,
            scope: scope,
            targetPageIDs: targetPageIDs,
            sessionDirectory: sessionDirectory
        )
    }

    private func applySinglePageAdjustment(
        session: ScanPageAdjustmentSession,
        sessionDirectory: URL
    ) async -> Bool {
        guard !isApplyingGeometry else { return false }
        guard var draft = document else { return false }
        guard draft.pages.contains(where: { $0.id == session.pageID }) else { return false }

        let operationID = UUID()
        geometryApplyOperationID = operationID
        isApplyingGeometry = true
        errorMessage = nil

        let page = draft.pages.first(where: { $0.id == session.pageID })!
        let geometry = session.workingGeometry
        let visualAdjustments = session.workingVisualAdjustments.normalizedForProcessing()
        let processor = geometryProcessor

        do {
            let updatedPage = try await Task.detached(priority: .userInitiated) {
                try await processor.applyAdjustment(
                    to: page,
                    geometry: geometry,
                    visualAdjustments: visualAdjustments,
                    sessionDirectory: sessionDirectory
                )
            }.value

            guard geometryApplyOperationID == operationID, document?.id == session.draftID else {
                return false
            }

            draft.updatePage(id: session.pageID) { existing in
                existing.geometry = updatedPage.geometry
                existing.visualAdjustments = updatedPage.visualAdjustments
                existing.processedImage = updatedPage.processedImage
                existing.thumbnailImage = updatedPage.thumbnailImage
                existing.thumbnailState = updatedPage.thumbnailState
                existing.processingState = updatedPage.processingState
                existing.processingError = updatedPage.processingError
                existing.processingFingerprint = updatedPage.processingFingerprint
            }
            draft.selectPage(id: session.pageID)
            document = draft
            finishAdjustmentSessionCleanup()
            navigateToDraftReview()
            return true
        } catch let error as ScanDraftError {
            guard geometryApplyOperationID == operationID else { return false }
            errorMessage = error.localizedDescription
            isApplyingGeometry = false
            geometryApplyOperationID = nil
            return false
        } catch {
            guard geometryApplyOperationID == operationID else { return false }
            errorMessage = ScanDraftError.visualAdjustmentFailure.localizedDescription
            isApplyingGeometry = false
            geometryApplyOperationID = nil
            return false
        }
    }

    private func applyBatchVisualAdjustment(
        session: ScanPageAdjustmentSession,
        scope: ScanVisualBatchApplyScope,
        targetPageIDs: [UUID],
        sessionDirectory: URL
    ) async -> Bool {
        guard let draft = document else { return false }

        let operationID = UUID()
        batchOperationID = operationID
        let cancellationFlag = ScanImportCancellationFlag()
        batchCancellationFlag = cancellationFlag
        isBatchProcessing = true
        isApplyingGeometry = true
        errorMessage = nil

        let snapshots = draft.pages
            .filter { targetPageIDs.contains($0.id) }
            .map { ScanDraftPageRollbackSnapshot(page: $0) }

        let request = ScanDraftVisualBatchRequest(
            operationID: operationID,
            draftID: session.draftID,
            sourcePageID: session.pageID,
            sourceGeometry: session.workingGeometry,
            visualAdjustments: session.workingVisualAdjustments.normalizedForProcessing(),
            targetPageIDs: targetPageIDs,
            updateSessionDefaults: scope == .allPages
        )

        batchProgress = ScanDraftVisualBatchProgress(
            completed: 0,
            total: targetPageIDs.count,
            currentPageID: targetPageIDs.first,
            currentPageNumber: 1,
            isCancelling: false
        )

        do {
            let result = try await visualBatchProcessor.execute(
                request: request,
                pages: draft.pages,
                sessionDirectory: sessionDirectory,
                isCancelled: { cancellationFlag.isCancelled },
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        guard self?.batchOperationID == operationID else { return }
                        self?.batchProgress = progress
                        self?.document?.processingStatus = .processingPages(
                            completed: progress.completed,
                            total: progress.total
                        )
                    }
                }
            )

            guard batchOperationID == operationID, document?.id == session.draftID else {
                return false
            }

            let committedPages = try visualBatchProcessor.commitBatchResults(
                request: request,
                result: result,
                snapshots: snapshots,
                sessionDirectory: sessionDirectory
            )

            guard batchOperationID == operationID, var updatedDraft = document else {
                return false
            }

            for committedPage in committedPages {
                updatedDraft.updatePage(id: committedPage.id) { existing in
                    if committedPage.id == session.pageID {
                        existing.geometry = committedPage.geometry
                    }
                    existing.visualAdjustments = committedPage.visualAdjustments
                    existing.processedImage = committedPage.processedImage
                    existing.thumbnailImage = committedPage.thumbnailImage
                    existing.thumbnailState = committedPage.thumbnailState
                    existing.processingState = committedPage.processingState
                    existing.processingError = committedPage.processingError
                    existing.processingFingerprint = committedPage.processingFingerprint
                }
            }

            if let sessionDefaults = result.sessionDefaultVisualAdjustments {
                updatedDraft.sessionDefaultVisualAdjustments = sessionDefaults
            }

            updatedDraft.selectPage(id: session.pageID)
            updatedDraft.processingStatus = .idle
            document = updatedDraft
            finishAdjustmentSessionCleanup(clearBatchSelection: true)
            navigateToDraftReview()
            return true
        } catch is CancellationError {
            guard batchOperationID == operationID else { return false }
            finishBatchCancellation()
            finishAdjustmentSessionCleanup(clearBatchSelection: false)
            navigateToDraftReview()
            return false
        } catch {
            guard batchOperationID == operationID else { return false }
            errorMessage = (error as? ScanDraftError)?.localizedDescription
                ?? ScanDraftError.visualBatchFailure.localizedDescription
            finishBatchCancellation()
            isApplyingGeometry = false
            batchOperationID = nil
            isBatchProcessing = false
            document?.processingStatus = .idle
            return false
        }
    }

    func cancelBatchProcessing() {
        guard isBatchProcessing else { return }
        batchCancellationFlag?.cancel()
        batchProgress = ScanDraftVisualBatchProgress(
            completed: batchProgress.completed,
            total: batchProgress.total,
            currentPageID: batchProgress.currentPageID,
            currentPageNumber: batchProgress.currentPageNumber,
            isCancelling: true
        )
        batchTask?.cancel()
    }

    private func finishBatchCancellation() {
        batchCancellationFlag = nil
        isBatchProcessing = false
        isApplyingGeometry = false
        batchOperationID = nil
        batchProgress = .idle
        document?.processingStatus = .idle
    }

    private func finishAdjustmentSessionCleanup(clearBatchSelection: Bool = false) {
        visualPreviewTask?.cancel()
        visualPreviewOperationID = nil
        visualPreviewImage = nil
        adjustmentSession = nil
        isApplyingGeometry = false
        isDetectingEdges = false
        isGeneratingVisualPreview = false
        isBatchProcessing = false
        geometryApplyOperationID = nil
        batchOperationID = nil
        batchProgress = .idle
        adjustmentSection = .appearance
        if clearBatchSelection {
            isMultiSelectionMode = false
            batchSelectionPageIDs = []
        }
    }

    func resolvedTargetPageIDs(for scope: ScanVisualBatchApplyScope, sourcePageID: UUID) -> [UUID] {
        guard let draft = document else { return [] }
        switch scope {
        case .thisPage:
            return [sourcePageID]
        case .selectedPages:
            let validIDs = Set(draft.pages.map(\.id))
            let selected = batchSelectionPageIDs.intersection(validIDs)
            return draft.pages.map(\.id).filter { selected.contains($0) }
        case .allPages:
            return draft.pages.map(\.id)
        }
    }

    func batchConfirmationMessage(
        for scope: ScanVisualBatchApplyScope,
        visualAdjustments: ScanVisualAdjustments
    ) -> String {
        let count: Int
        if let session = adjustmentSession {
            count = resolvedTargetPageIDs(for: scope, sourcePageID: session.pageID).count
        } else {
            count = 0
        }
        let modeName = visualAdjustments.mode.displayName
        return "Apply \(modeName) and current adjustments to \(count) pages? Page crops and rotations will remain unchanged."
    }

    // MARK: - Batch page selection

    func enterMultiSelectionMode() {
        isMultiSelectionMode = true
        repairBatchSelectionIfNeeded()
    }

    func exitMultiSelectionMode() {
        isMultiSelectionMode = false
        batchSelectionPageIDs = []
    }

    func toggleBatchSelection(pageID: UUID) {
        guard document?.pages.contains(where: { $0.id == pageID }) == true else { return }
        if batchSelectionPageIDs.contains(pageID) {
            batchSelectionPageIDs.remove(pageID)
        } else {
            batchSelectionPageIDs.insert(pageID)
        }
    }

    func selectAllPagesForBatch() {
        guard let draft = document else { return }
        batchSelectionPageIDs = Set(draft.pages.map(\.id))
    }

    func repairBatchSelectionIfNeeded() {
        guard let draft = document else {
            batchSelectionPageIDs = []
            return
        }
        let validIDs = Set(draft.pages.map(\.id))
        batchSelectionPageIDs = batchSelectionPageIDs.intersection(validIDs)
    }

    var batchSelectionCount: Int {
        batchSelectionPageIDs.count
    }

    func handleAcquisitionCancelled() {
        if hasActiveDraft {
            navigateToDraftReview()
        } else {
            discardDraftSession()
        }
    }

    // MARK: - Shared acquisition session preparation

    func prepareSessionForAcquisition(context: ScanAcquisitionImportContext) throws {
        acquisitionImportContext = context
        cameraScanCompletionHandled = false
        photosSelectionHandled = false
        photosImportOperationID = UUID()
        photosImportCancellationFlag = ScanImportCancellationFlag()

        switch context {
        case .newDocument:
            if document == nil {
                let draft = ScanDraftDocument()
                try storage.createSessionDirectory(for: draft.id)
                document = draft
                emptySessionCreatedForImport = true
            } else if document?.isEmpty == true {
                emptySessionCreatedForImport = true
            } else {
                emptySessionCreatedForImport = false
            }
            preImportPageIDs = []

        case .addToExistingDraft:
            guard let draft = document, !draft.isEmpty else {
                throw ScanDraftError.sessionNotFound
            }
            preImportPageIDs = Set(draft.pages.map(\.id))
            emptySessionCreatedForImport = false
        }
    }

    // MARK: - Camera acquisition

    @discardableResult
    func requestCameraScan(context: ScanAcquisitionImportContext) async -> Bool {
        errorMessage = nil
        cameraScanCompletionHandled = false

        guard scannerAvailability.isDocumentScannerSupported else {
            errorMessage = ScanDraftError.scannerUnsupported.localizedDescription
            return false
        }

        do {
            try prepareSessionForAcquisition(context: context)
        } catch let error as ScanDraftError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = ScanDraftError.draftModelUpdateFailure.localizedDescription
            return false
        }

        let permissionStatus = permissionChecker.authorizationStatus()
        switch permissionStatus {
        case .authorized:
            isDocumentScannerPresented = true
            return true
        case .notDetermined:
            let requestedStatus = await permissionChecker.requestAccess()
            return await handlePermissionStatus(requestedStatus)
        case .denied:
            errorMessage = ScanDraftError.cameraPermissionDenied.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return false
        case .restricted:
            errorMessage = ScanDraftError.cameraPermissionRestricted.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return false
        }
    }

    func presentDocumentScannerIfNeeded() {
        guard scannerAvailability.isDocumentScannerSupported,
              !isImportingCameraScan,
              !cameraScanCompletionHandled else {
            return
        }
        isDocumentScannerPresented = true
    }

    func handleVisionKitScanCompleted(_ scan: VNDocumentCameraScan) async {
        await handleVisionKitScanCompleted(VisionKitDocumentCameraScanBridge(scan: scan))
    }

    func handleVisionKitScanCompleted(_ scan: any VNDocumentCameraScanBridge) async {
        guard !cameraScanCompletionHandled else { return }
        cameraScanCompletionHandled = true
        isDocumentScannerPresented = false

        guard scan.pageCount > 0 else {
            errorMessage = ScanDraftError.emptyDraft.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return
        }

        await importVisionKitScan(scan)
    }

    func handleVisionKitScanCancelled() {
        guard !cameraScanCompletionHandled else { return }
        cameraScanCompletionHandled = true
        isDocumentScannerPresented = false
        errorMessage = nil

        switch acquisitionImportContext {
        case .newDocument:
            if document?.isEmpty ?? true {
                discardDraftSession()
            } else {
                navigateToDraftReview()
            }
        case .addToExistingDraft:
            navigateToDraftReview()
        }
    }

    func handleVisionKitScanFailed(_ error: ScanDraftError) {
        guard !cameraScanCompletionHandled else { return }
        cameraScanCompletionHandled = true
        isDocumentScannerPresented = false
        errorMessage = error.localizedDescription
        rollbackFailedImport()
    }

    func beginAddPagesCameraScan() async -> Bool {
        let ready = await requestCameraScan(context: .addToExistingDraft)
        if ready {
            navigateToCameraAcquisition()
        }
        return ready
    }

    private func handlePermissionStatus(_ status: ScanCameraAuthorizationStatus) async -> Bool {
        switch status {
        case .authorized:
            isDocumentScannerPresented = true
            return true
        case .denied:
            errorMessage = ScanDraftError.cameraPermissionDenied.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return false
        case .restricted:
            errorMessage = ScanDraftError.cameraPermissionRestricted.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return false
        case .notDetermined:
            errorMessage = ScanDraftError.cameraPermissionDenied.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return false
        }
    }

    private func importVisionKitScan(_ scan: any VNDocumentCameraScanBridge) async {
        guard !isImportingCameraScan else { return }
        guard var draft = document else {
            errorMessage = ScanDraftError.sessionNotFound.localizedDescription
            return
        }

        isImportingCameraScan = true
        defer { isImportingCameraScan = false }

        let sessionDirectory = storage.sessionDirectory(for: draft.id)
        let sessionDefaults = draft.sessionDefaultVisualAdjustments.copied()
        let existingPagesSnapshot = draft.pages

        do {
            let importer = cameraScanImporter
            let importedPages = try await Task.detached(priority: .userInitiated) {
                try importer.importVisionKitScan(
                    scan,
                    sessionDirectory: sessionDirectory,
                    sessionDefaults: sessionDefaults
                )
            }.value

            draft.pages = existingPagesSnapshot
            draft.addPages(importedPages)

            if draft.selectedPageID == nil {
                draft.selectPage(id: draft.pages.first?.id)
            }

            document = draft
            emptySessionCreatedForImport = false
            preImportPageIDs = Set(draft.pages.map(\.id))
            navigateToDraftReview()
            scheduleProcessingAllPages()
        } catch let error as ScanDraftError {
            document?.pages = existingPagesSnapshot
            errorMessage = error.localizedDescription
            rollbackFailedImport()
        } catch {
            document?.pages = existingPagesSnapshot
            errorMessage = ScanDraftError.draftModelUpdateFailure.localizedDescription
            rollbackFailedImport()
        }
    }

    // MARK: - Photos acquisition

    @discardableResult
    func requestPhotosImport(context: ScanAcquisitionImportContext) -> Bool {
        guard !isImportingPhotos else { return false }

        errorMessage = nil

        do {
            try prepareSessionForAcquisition(context: context)
            return true
        } catch let error as ScanDraftError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = ScanDraftError.draftModelUpdateFailure.localizedDescription
            return false
        }
    }

    func beginAddPagesPhotosImport() -> Bool {
        let ready = requestPhotosImport(context: .addToExistingDraft)
        if ready {
            navigateToPhotosAcquisition()
        }
        return ready
    }

    func handlePhotosPickerCancelled() {
        guard !photosSelectionHandled else { return }
        guard !isImportingPhotos else { return }

        photosSelectionHandled = true
        errorMessage = nil

        switch acquisitionImportContext {
        case .newDocument:
            if document?.isEmpty ?? true {
                discardDraftSession()
            } else {
                navigateToDraftReview()
            }
        case .addToExistingDraft:
            navigateToDraftReview()
        }
    }

    func handlePhotosSelection(_ pickerItems: [PhotosPickerItem]) async {
        guard photosImportOperationID != nil else { return }
        guard !photosSelectionHandled else { return }
        guard !isImportingPhotos else { return }

        guard !pickerItems.isEmpty else {
            handlePhotosPickerCancelled()
            return
        }

        if pickerItems.count > ScanPhotosImportLimits.maxSelectionCount {
            errorMessage = "You can import up to \(ScanPhotosImportLimits.maxSelectionCount) photos at once."
            return
        }

        photosSelectionHandled = true
        let orderedItems = ScanPhotosOrderedItemsBuilder.orderedItems(from: pickerItems)
        let assetLoader = PhotosPickerItemAssetLoader(items: pickerItems)
        await importPhotos(orderedItems: orderedItems, assetLoader: assetLoader)
    }

    func handlePhotosSelection(
        orderedItems: [ScanOrderedPhotoImportItem],
        assetLoader: any ScanPhotosAssetLoading
    ) async {
        guard photosImportOperationID != nil else { return }
        guard !photosSelectionHandled else { return }
        guard !isImportingPhotos else { return }
        guard !orderedItems.isEmpty else {
            handlePhotosPickerCancelled()
            return
        }

        photosSelectionHandled = true
        await importPhotos(orderedItems: orderedItems, assetLoader: assetLoader)
    }

    func cancelPhotosImport() {
        photosImportCancellationFlag?.cancel()
        photosImportTask?.cancel()
        photosImportTask = nil
        isImportingPhotos = false
        photosImportProgress = nil
    }

    private func importPhotos(
        orderedItems: [ScanOrderedPhotoImportItem],
        assetLoader: any ScanPhotosAssetLoading
    ) async {
        guard !isImportingPhotos else { return }
        guard var draft = document else {
            errorMessage = ScanDraftError.sessionNotFound.localizedDescription
            rollbackEmptyImportSessionIfNeeded()
            return
        }

        let operationID = photosImportOperationID
        let cancellationFlag = photosImportCancellationFlag
        isImportingPhotos = true
        photosImportProgress = ScanPhotosImportProgress(total: orderedItems.count, completed: 0)

        let sessionDirectory = storage.sessionDirectory(for: draft.id)
        let sessionDefaults = draft.sessionDefaultVisualAdjustments.copied()
        let existingPagesSnapshot = draft.pages
        let importer = photosSelectionImporter

        photosImportTask = Task { [weak self] in
            guard let self else { return }

            do {
                let importedPages = try await Task.detached(priority: .userInitiated) {
                    try await importer.importPhotos(
                        orderedItems: orderedItems,
                        assetLoader: assetLoader,
                        sessionDirectory: sessionDirectory,
                        sessionDefaults: sessionDefaults,
                        progressHandler: { progress in
                            Task { @MainActor in
                                guard self.photosImportOperationID == operationID else { return }
                                self.photosImportProgress = progress
                            }
                        },
                        isCancelled: {
                            cancellationFlag?.isCancelled == true || Task.isCancelled
                        }
                    )
                }.value

                guard self.photosImportOperationID == operationID else { return }
                guard cancellationFlag?.isCancelled != true else {
                    self.finalizePhotosImportCancellation(existingPagesSnapshot: existingPagesSnapshot)
                    return
                }

                draft.pages = existingPagesSnapshot
                draft.addPages(importedPages)

                if draft.selectedPageID == nil {
                    draft.selectPage(id: draft.pages.first?.id)
                }

                self.document = draft
                self.emptySessionCreatedForImport = false
                self.preImportPageIDs = Set(draft.pages.map(\.id))
                self.isImportingPhotos = false
                self.photosImportProgress = nil
                self.photosImportTask = nil
                self.navigateToDraftReview()
                self.scheduleProcessingAllPages()
            } catch let error as ScanDraftError where error == .photosImportCancelled {
                guard self.photosImportOperationID == operationID else { return }
                self.finalizePhotosImportCancellation(existingPagesSnapshot: existingPagesSnapshot)
            } catch let error as ScanDraftError {
                guard self.photosImportOperationID == operationID else { return }
                self.document?.pages = existingPagesSnapshot
                if error.localizedDescription != nil {
                    self.errorMessage = error.localizedDescription
                }
                self.rollbackFailedImport()
                self.isImportingPhotos = false
                self.photosImportProgress = nil
                self.photosImportTask = nil
            } catch {
                guard self.photosImportOperationID == operationID else { return }
                self.document?.pages = existingPagesSnapshot
                self.errorMessage = ScanDraftError.photosAssetLoadFailure.localizedDescription
                self.rollbackFailedImport()
                self.isImportingPhotos = false
                self.photosImportProgress = nil
                self.photosImportTask = nil
            }
        }

        await photosImportTask?.value
    }

    private func finalizePhotosImportCancellation(existingPagesSnapshot: [ScanDraftPage]) {
        document?.pages = existingPagesSnapshot
        errorMessage = nil
        rollbackFailedImport()
        isImportingPhotos = false
        photosImportProgress = nil
        photosImportTask = nil
        photosImportCancellationFlag = nil
    }

    private func rollbackEmptyImportSessionIfNeeded() {
        guard acquisitionImportContext == .newDocument,
              document?.isEmpty ?? true,
              emptySessionCreatedForImport else {
            return
        }

        if let documentID = document?.id {
            try? storage.deleteSession(for: documentID)
        }
        document = nil
        emptySessionCreatedForImport = false
        isDocumentScannerPresented = false
        preImportPageIDs = []
        photosImportOperationID = nil
    }

    private func rollbackFailedImport() {
        guard var draft = document else { return }

        switch acquisitionImportContext {
        case .newDocument:
            if preImportPageIDs.isEmpty {
                try? storage.deleteSession(for: draft.id)
                document = nil
                emptySessionCreatedForImport = false
            } else {
                draft.pages = draft.pages.filter { preImportPageIDs.contains($0.id) }
                document = draft
            }
        case .addToExistingDraft:
            draft.pages = draft.pages.filter { preImportPageIDs.contains($0.id) }
            if let selected = draft.pages.last?.id {
                draft.selectPage(id: selected)
            }
            document = draft
        }
    }

    // MARK: - Navigation

    func navigateToSourceSelection() {
        navigationPath = [.sourceSelection]
    }

    func navigateToCameraAcquisition() {
        if navigationPath.last != .cameraAcquisition {
            navigationPath.append(.cameraAcquisition)
        }
    }

    func navigateToPhotosAcquisition() {
        if navigationPath.last != .photosAcquisition {
            navigationPath.append(.photosAcquisition)
        }
    }

    func navigateToDraftReview() {
        navigationPath = [.draftReview]
    }

    func navigateToPageAdjustment(pageID: UUID) {
        if navigationPath.last != .pageAdjustment(pageID: pageID) {
            navigationPath.append(.pageAdjustment(pageID: pageID))
        }
    }

    func navigateToPDFGenerationProgress() {
        if navigationPath.last != .pdfGenerationProgress {
            navigationPath.append(.pdfGenerationProgress)
        }
    }

    // MARK: - Acquisition convergence

    func importAcquiredImages(_ payloads: [ScanAcquiredImagePayload]) async throws {
        guard !payloads.isEmpty else {
            throw ScanDraftError.emptyDraft
        }
        guard var draft = document else {
            throw ScanDraftError.sessionNotFound
        }

        let sessionDirectory = storage.sessionDirectory(for: draft.id)
        var importedPages: [ScanDraftPage] = []
        importedPages.reserveCapacity(payloads.count)

        for payload in payloads {
            let page = try storage.importOriginalImage(
                data: payload.data,
                pageID: UUID(),
                sourceType: payload.sourceType,
                sessionDirectory: sessionDirectory
            )
            var pageWithDefaults = page
            pageWithDefaults.visualAdjustments = draft.sessionDefaultVisualAdjustments.copied()
            importedPages.append(pageWithDefaults)
        }

        draft.addPages(importedPages)
        document = draft
        navigateToDraftReview()
        scheduleProcessingAllPages()
    }

    // MARK: - Draft page operations

    func selectPage(id: UUID?) {
        guard var draft = document else { return }
        draft.selectedPageID = id
        if !isMultiSelectionMode {
            if let id {
                draft.selectedPageIDs = [id]
            } else {
                draft.selectedPageIDs.removeAll()
            }
        }
        document = draft
    }

    func setMultiSelection(_ pageIDs: Set<UUID>) {
        guard var draft = document else { return }
        draft.setMultiSelection(pageIDs)
        document = draft
    }

    func removePage(id: UUID) {
        deletePages(ids: [id])
    }

    func pageIDsForDeletion() -> Set<UUID> {
        guard let draft = document else { return [] }
        let validIDs = Set(draft.pages.map(\.id))

        if isMultiSelectionMode {
            return batchSelectionPageIDs.intersection(validIDs)
        }

        if let selectedPageID = draft.selectedPageID, validIDs.contains(selectedPageID) {
            return [selectedPageID]
        }

        return []
    }

    func deletePages(ids: Set<UUID>) {
        guard var draft = document, let sessionDirectory = sessionDirectory else { return }
        guard !ids.isEmpty else { return }

        let pagesToDelete = draft.pages.filter { ids.contains($0.id) }
        guard !pagesToDelete.isEmpty else { return }

        for page in pagesToDelete {
            storage.deletePageAssets(for: page, sessionDirectory: sessionDirectory)
        }

        let removedIDs = draft.removePages(ids: ids)
        guard !removedIDs.isEmpty else { return }

        document = draft
        repairBatchSelectionIfNeeded()

        if isMultiSelectionMode, batchSelectionPageIDs.isEmpty {
            exitMultiSelectionMode()
        }
    }

    func duplicatePage(id: UUID) {
        guard var draft = document, let sessionDirectory = sessionDirectory else { return }
        guard let sourcePage = draft.pages.first(where: { $0.id == id }) else {
            errorMessage = ScanDraftError.draftModelUpdateFailure.localizedDescription
            return
        }

        let newPageID = UUID()
        do {
            let duplicatedPage = try storage.duplicatePageAssets(
                from: sourcePage,
                newPageID: newPageID,
                sessionDirectory: sessionDirectory
            )
            draft.insertDuplicatedPage(duplicatedPage, after: id)
            document = draft
        } catch {
            storage.deletePageAssets(
                for: ScanDraftPage(
                    id: newPageID,
                    sourceType: sourcePage.sourceType,
                    originalImage: ScanDraftImageReference(
                        relativePath: "\(ScanDraftSessionStorage.originalsDirectoryName)/\(newPageID.uuidString).jpg"
                    ),
                    originalPixelSize: sourcePage.originalPixelSize
                ),
                sessionDirectory: sessionDirectory
            )
            errorMessage = (error as? ScanDraftError)?.localizedDescription
                ?? ScanDraftError.draftModelUpdateFailure.localizedDescription
        }
    }

    func rotateSelectedPage() {
        guard let pageID = document?.selectedPageID else { return }
        rotatePage(id: pageID)
    }

    func reorderPages(from source: Int, to destination: Int) {
        guard var draft = document else { return }
        draft.reorderPages(from: source, to: destination)
        document = draft
    }

    func rotatePage(id: UUID) {
        guard var draft = document else { return }
        draft.rotatePage(id: id)
        document = draft
        scheduleProcessing(for: [id])
    }

    func updatePageGeometry(id: UUID, geometry: ScanPageGeometry) {
        guard var draft = document else { return }
        draft.updatePage(id: id) { page in
            page.geometry = geometry
            page.processingState = .pending
            page.processingFingerprint = nil
            page.processedImage = nil
            page.thumbnailState = .notGenerated
            page.thumbnailImage = nil
        }
        document = draft
        scheduleProcessing(for: [id])
    }

    func applyVisualAdjustments(_ adjustments: ScanVisualAdjustments, toPageIDs: Set<UUID>) {
        guard var draft = document else { return }
        draft.applyVisualAdjustments(adjustments, toPageIDs: toPageIDs)
        document = draft
        scheduleProcessing(for: Array(toPageIDs))
    }

    func applyVisualAdjustmentsToAll(_ adjustments: ScanVisualAdjustments) {
        guard var draft = document else { return }
        draft.applyVisualAdjustmentsToAll(adjustments)
        document = draft
        scheduleProcessing(for: draft.pages.map(\.id))
    }

    func updateSessionDefaultVisualAdjustments(_ adjustments: ScanVisualAdjustments) {
        guard var draft = document else { return }
        draft.sessionDefaultVisualAdjustments = adjustments.copied()
        draft.hasUnsavedChanges = true
        document = draft
    }

    // MARK: - Processing

    func scheduleProcessing(for pageIDs: [UUID]) {
        guard let draft = document, let sessionDirectory = sessionDirectory else { return }
        let targets = draft.pages.filter { pageIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        processingTask?.cancel()
        processingTask = Task { [weak self] in
            guard let self else { return }
            await self.processPages(targets, sessionDirectory: sessionDirectory)
        }
    }

    func scheduleProcessingAllPages() {
        guard let draft = document else { return }
        scheduleProcessing(for: draft.pages.map(\.id))
    }

    private func processPages(_ pages: [ScanDraftPage], sessionDirectory: URL) async {
        guard let draftID = document?.id else { return }

        isProcessingPages = true
        defer {
            if isActiveSession(draftID) {
                isProcessingPages = false
            }
        }

        guard var draft = document, draft.id == draftID else { return }
        draft.processingStatus = .processingPages(completed: 0, total: pages.count)
        document = draft

        var completed = 0
        do {
            let processedPages = try await processingOrchestrator.processPages(
                pages,
                sessionDirectory: sessionDirectory,
                onPageCompleted: { [weak self] page in
                    Task { @MainActor in
                        guard let self, self.isActiveSession(draftID) else { return }
                        self.mergeProcessedPage(page)
                        completed += 1
                        self.document?.processingStatus = .processingPages(
                            completed: completed,
                            total: pages.count
                        )
                    }
                }
            )

            guard isActiveSession(draftID) else { return }

            for page in processedPages {
                mergeProcessedPage(page)
            }

            document?.processingStatus = .idle
        } catch is CancellationError {
            guard isActiveSession(draftID) else { return }
            document?.processingStatus = .idle
        } catch {
            guard isActiveSession(draftID) else { return }
            document?.processingStatus = .failed
            errorMessage = (error as? ScanDraftError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func mergeProcessedPage(_ page: ScanDraftPage) {
        guard var draft = document else { return }
        guard draft.pages.contains(where: { $0.id == page.id }) else { return }
        draft.updatePage(id: page.id) { existing in
            existing.processedImage = page.processedImage
            existing.thumbnailImage = page.thumbnailImage
            existing.thumbnailState = page.thumbnailState
            existing.processingState = page.processingState
            existing.processingError = page.processingError
            existing.processingFingerprint = page.processingFingerprint
        }
        document = draft
    }

    // MARK: - PDF generation and editor handoff

    func createPDFAndOpenEditor(
        editorViewModel: PDFEditorViewModel,
        displayName: String = "Scanned Document",
        onSuccess: @escaping () -> Void
    ) {
        guard !isGeneratingPDF else { return }
        guard let draft = document, !draft.isEmpty else {
            errorMessage = ScanDraftError.emptyDraft.localizedDescription
            return
        }

        pdfGenerationTask?.cancel()
        pdfGenerationTask = Task { [weak self] in
            await self?.performPDFCreationAndHandoff(
                editorViewModel: editorViewModel,
                displayName: displayName,
                onSuccess: onSuccess
            )
        }
    }

    func cancelPDFGeneration() {
        guard isGeneratingPDF else { return }
        pdfGenerationProgress.isCancelling = true
        pdfGenerationTask?.cancel()
    }

    func generatePDF(displayName: String = "Scanned Document") async throws -> URL {
        isGeneratingPDF = true
        navigateToPDFGenerationProgress()
        defer { isGeneratingPDF = false }

        do {
            return try await buildPDFFile(displayName: displayName)
        } catch {
            cleanupFailedPDFGeneration()
            throw error
        }
    }

    func handoffToEditor(editorViewModel: PDFEditorViewModel) async throws {
        guard let pdfURL = document?.generatedPDFURL else {
            throw ScanDraftError.pdfGenerationFailure
        }

        pdfGenerationProgress = ScanDraftPDFGenerationProgress(
            phase: .openingEditor,
            currentPage: pdfGenerationProgress.totalPages,
            totalPages: pdfGenerationProgress.totalPages,
            isCancelling: false
        )
        try await editorHandoff.handoff(pdfURL: pdfURL, to: editorViewModel)
    }

    private func performPDFCreationAndHandoff(
        editorViewModel: PDFEditorViewModel,
        displayName: String,
        onSuccess: @escaping () -> Void
    ) async {
        guard let draftID = document?.id else { return }

        let totalPages = document?.pages.count ?? 0
        isGeneratingPDF = true
        navigateToPDFGenerationProgress()
        pdfGenerationProgress = ScanDraftPDFGenerationProgress(
            phase: .preparingPages,
            currentPage: 0,
            totalPages: totalPages,
            isCancelling: false
        )
        errorMessage = nil
        defer {
            if isActiveSession(draftID) || document == nil {
                isGeneratingPDF = false
            }
            pdfGenerationTask = nil
        }

        do {
            _ = try await buildPDFFile(displayName: displayName, draftID: draftID)
            guard isActiveSession(draftID) else { return }
            try await handoffToEditor(editorViewModel: editorViewModel)
            guard isActiveSession(draftID) else { return }
            pdfGenerationProgress = .idle
            onSuccess()
        } catch is CancellationError {
            guard isActiveSession(draftID) else { return }
            cleanupFailedPDFGeneration()
            navigateToDraftReview()
        } catch {
            guard isActiveSession(draftID) else { return }
            errorMessage = (error as? ScanDraftError)?.localizedDescription ?? error.localizedDescription
            cleanupFailedPDFGeneration()
            navigateToDraftReview()
        }
    }

    private func buildPDFFile(displayName: String, draftID: UUID? = nil) async throws -> URL {
        let activeDraftID = draftID ?? document?.id
        guard let draft = document,
              let activeDraftID,
              draft.id == activeDraftID,
              !draft.isEmpty else {
            throw ScanDraftError.emptyDraft
        }
        guard let sessionDirectory = sessionDirectory else {
            throw ScanDraftError.sessionNotFound
        }

        document?.processingStatus = .generatingPDF

        let pdfURL = try await pdfGenerator.generatePDF(
            from: draft.pages,
            sessionDirectory: sessionDirectory,
            displayName: displayName,
            onProgress: { [weak self] update in
                Task { @MainActor in
                    guard let self, self.isActiveSession(activeDraftID) else { return }
                    self.pdfGenerationProgress = ScanDraftPDFGenerationProgress(
                        phase: update.phase,
                        currentPage: update.currentPage,
                        totalPages: update.totalPages,
                        isCancelling: self.pdfGenerationProgress.isCancelling
                    )
                }
            },
            onPagePrepared: { [weak self] page in
                Task { @MainActor in
                    guard let self, self.isActiveSession(activeDraftID) else { return }
                    self.mergeProcessedPage(page)
                }
            }
        )

        guard isActiveSession(activeDraftID) else {
            throw CancellationError()
        }

        document?.generatedPDFURL = pdfURL
        document?.processingStatus = .pdfReady
        return pdfURL
    }

    private func isActiveSession(_ draftID: UUID) -> Bool {
        document?.id == draftID
    }

    private func cleanupFailedPDFGeneration() {
        if let sessionDirectory = sessionDirectory {
            storage.deleteGeneratedPDFStaging(in: sessionDirectory)
        }
        document?.generatedPDFURL = nil
        document?.processingStatus = .idle
        pdfGenerationProgress = .idle
    }
}

extension ScanDraftSessionViewModel: ScanImageAcquisitionCoordinating {
    func acquisitionDidFinish(payloads: [ScanAcquiredImagePayload]) async {
        try? await importAcquiredImages(payloads)
    }

    func acquisitionDidCancel() async {
        handleAcquisitionCancelled()
    }
}
