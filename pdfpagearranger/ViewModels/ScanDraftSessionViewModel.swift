import Foundation
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
    var isDocumentScannerPresented = false
    var errorMessage: String?

    private let storage: ScanDraftSessionStorage
    private let processingOrchestrator: ScanPageProcessingOrchestrator
    private let pdfGenerator: any ScanDraftPDFGenerating
    private let editorHandoff: ScanEditorHandoffService
    private let cameraScanImporter: ScanCameraScanImporter
    private let permissionChecker: any ScanCameraPermissionChecking
    private let scannerAvailability: any ScanDocumentScannerAvailabilityChecking
    private var processingTask: Task<Void, Never>?
    private var cameraImportContext: ScanCameraImportContext = .newDocument
    private var preImportPageIDs: Set<UUID> = []
    private var emptySessionCreatedForCamera = false
    private var cameraScanCompletionHandled = false

    init(
        storage: ScanDraftSessionStorage = ScanDraftSessionStorage(),
        processingOrchestrator: ScanPageProcessingOrchestrator = ScanPageProcessingOrchestrator(),
        pdfGenerator: any ScanDraftPDFGenerating = UnimplementedScanDraftPDFGenerator(),
        editorHandoff: ScanEditorHandoffService? = nil,
        cameraScanImporter: ScanCameraScanImporter? = nil,
        permissionChecker: (any ScanCameraPermissionChecking)? = nil,
        scannerAvailability: (any ScanDocumentScannerAvailabilityChecking)? = nil
    ) {
        self.storage = storage
        self.processingOrchestrator = processingOrchestrator
        self.pdfGenerator = pdfGenerator
        self.editorHandoff = editorHandoff ?? ScanEditorHandoffService()
        self.cameraScanImporter = cameraScanImporter ?? ScanCameraScanImporter(storage: storage)
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
        processingTask?.cancel()
        processingTask = nil

        if let documentID = document?.id {
            try? storage.deleteSession(for: documentID)
        }

        document = nil
        navigationPath = []
        isProcessingPages = false
        isGeneratingPDF = false
        isImportingCameraScan = false
        isDocumentScannerPresented = false
        errorMessage = nil
        preImportPageIDs = []
        emptySessionCreatedForCamera = false
        cameraScanCompletionHandled = false
    }

    func handleAcquisitionCancelled() {
        if hasActiveDraft {
            navigateToDraftReview()
        } else {
            discardDraftSession()
        }
    }

    // MARK: - Camera acquisition

    @discardableResult
    func requestCameraScan(context: ScanCameraImportContext) async -> Bool {
        errorMessage = nil
        cameraScanCompletionHandled = false

        guard scannerAvailability.isDocumentScannerSupported else {
            errorMessage = ScanDraftError.scannerUnsupported.localizedDescription
            return false
        }

        do {
            try prepareSessionForCameraScan(context: context)
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
            rollbackEmptyCameraSessionIfNeeded()
            return false
        case .restricted:
            errorMessage = ScanDraftError.cameraPermissionRestricted.localizedDescription
            rollbackEmptyCameraSessionIfNeeded()
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
            rollbackEmptyCameraSessionIfNeeded()
            return
        }

        await importVisionKitScan(scan)
    }

    func handleVisionKitScanCancelled() {
        guard !cameraScanCompletionHandled else { return }
        cameraScanCompletionHandled = true
        isDocumentScannerPresented = false
        errorMessage = nil

        switch cameraImportContext {
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
        rollbackFailedCameraImport()
    }

    func beginAddPagesCameraScan() async -> Bool {
        cameraImportContext = .addToExistingDraft
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
            rollbackEmptyCameraSessionIfNeeded()
            return false
        case .restricted:
            errorMessage = ScanDraftError.cameraPermissionRestricted.localizedDescription
            rollbackEmptyCameraSessionIfNeeded()
            return false
        case .notDetermined:
            errorMessage = ScanDraftError.cameraPermissionDenied.localizedDescription
            rollbackEmptyCameraSessionIfNeeded()
            return false
        }
    }

    func prepareSessionForCameraScan(context: ScanCameraImportContext) throws {
        cameraImportContext = context
        cameraScanCompletionHandled = false

        switch context {
        case .newDocument:
            if document == nil {
                let draft = ScanDraftDocument()
                try storage.createSessionDirectory(for: draft.id)
                document = draft
                emptySessionCreatedForCamera = true
            } else if document?.isEmpty == true {
                emptySessionCreatedForCamera = true
            } else {
                emptySessionCreatedForCamera = false
            }
            preImportPageIDs = []

        case .addToExistingDraft:
            guard let draft = document, !draft.isEmpty else {
                throw ScanDraftError.sessionNotFound
            }
            preImportPageIDs = Set(draft.pages.map(\.id))
            emptySessionCreatedForCamera = false
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

            if cameraImportContext == .addToExistingDraft,
               let firstImported = importedPages.first?.id {
                draft.selectPage(id: firstImported)
            } else if draft.selectedPageID == nil {
                draft.selectPage(id: importedPages.first?.id)
            }

            document = draft
            emptySessionCreatedForCamera = false
            preImportPageIDs = Set(draft.pages.map(\.id))
            navigateToDraftReview()
            scheduleProcessingAllPages()
        } catch let error as ScanDraftError {
            document?.pages = existingPagesSnapshot
            errorMessage = error.localizedDescription
            rollbackFailedCameraImport()
        } catch {
            document?.pages = existingPagesSnapshot
            errorMessage = ScanDraftError.draftModelUpdateFailure.localizedDescription
            rollbackFailedCameraImport()
        }
    }

    private func rollbackEmptyCameraSessionIfNeeded() {
        guard cameraImportContext == .newDocument,
              document?.isEmpty ?? true,
              emptySessionCreatedForCamera else {
            return
        }

        if let documentID = document?.id {
            try? storage.deleteSession(for: documentID)
        }
        document = nil
        emptySessionCreatedForCamera = false
        isDocumentScannerPresented = false
        preImportPageIDs = []
    }

    private func rollbackFailedCameraImport() {
        guard var draft = document else { return }

        switch cameraImportContext {
        case .newDocument:
            if preImportPageIDs.isEmpty {
                discardDraftSession()
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
        draft.selectPage(id: id)
        document = draft
    }

    func setMultiSelection(_ pageIDs: Set<UUID>) {
        guard var draft = document else { return }
        draft.setMultiSelection(pageIDs)
        document = draft
    }

    func removePage(id: UUID) {
        guard var draft = document else { return }
        draft.removePage(id: id)
        document = draft
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
        isProcessingPages = true
        defer { isProcessingPages = false }

        guard var draft = document else { return }
        draft.processingStatus = .processingPages(completed: 0, total: pages.count)
        document = draft

        var completed = 0
        do {
            let processedPages = try await processingOrchestrator.processPages(
                pages,
                sessionDirectory: sessionDirectory,
                onPageCompleted: { [weak self] page in
                    Task { @MainActor in
                        self?.mergeProcessedPage(page)
                        completed += 1
                        self?.document?.processingStatus = .processingPages(
                            completed: completed,
                            total: pages.count
                        )
                    }
                }
            )

            for page in processedPages {
                mergeProcessedPage(page)
            }

            document?.processingStatus = .idle
        } catch {
            document?.processingStatus = .failed
            errorMessage = (error as? ScanDraftError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func mergeProcessedPage(_ page: ScanDraftPage) {
        guard var draft = document else { return }
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

    func generatePDF(displayName: String = "Scanned Document") async throws -> URL {
        guard let draft = document, !draft.isEmpty else {
            throw ScanDraftError.emptyDraft
        }
        guard let sessionDirectory = sessionDirectory else {
            throw ScanDraftError.sessionNotFound
        }

        isGeneratingPDF = true
        navigateToPDFGenerationProgress()
        defer { isGeneratingPDF = false }

        document?.processingStatus = .generatingPDF

        let pdfURL = try await pdfGenerator.generatePDF(
            from: draft.pages,
            sessionDirectory: sessionDirectory,
            displayName: displayName
        )

        document?.generatedPDFURL = pdfURL
        document?.processingStatus = .pdfReady
        document?.hasUnsavedChanges = false
        return pdfURL
    }

    func handoffToEditor(editorViewModel: PDFEditorViewModel) async throws {
        guard let pdfURL = document?.generatedPDFURL else {
            throw ScanDraftError.pdfGenerationFailure
        }

        let sessionID = document?.id
        try await editorHandoff.handoff(pdfURL: pdfURL, to: editorViewModel)

        if let sessionID {
            try? storage.deleteSession(for: sessionID)
        }
        document = nil
        navigationPath = []
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
