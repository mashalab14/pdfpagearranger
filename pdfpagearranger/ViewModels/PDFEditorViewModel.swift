import Foundation
import PDFKit
import SwiftUI
import UIKit

@Observable
@MainActor
final class PDFEditorViewModel {
    private(set) var pages: [PageItem] = []
    private(set) var documentName: String = ""
    private(set) var sourceDocument: PDFDocument?
    private(set) var localSourceURL: URL?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var undoStack: [EditorSnapshot] = []
    private var pageObjectsByPage: [UUID: [PageObject]] = [:]
    private var annotationsByPage: [UUID: [PageAnnotation]] = [:]
    private var imageAssets: [UUID: UIImage] = [:]
    private var overlayRevisions: [UUID: Int] = [:]
    private(set) var pageNumberSettings: PageNumberSettings = .default
    private(set) var watermarkSettings: WatermarkSettings = .default
    private(set) var documentSearch = DocumentSearchState()
    private var searchResultsCacheKey: String?
    private var searchResultsCache: DocumentSearchResults?
    private let pdfService = PDFService()
    private let compressionService = CompressionService()
    let proGate = ProGate()

    init() {
        if let pageCount = UITestLaunchConfiguration.autoImportPageCount {
            Task {
                await self.importUITestDocument(pageCount: pageCount)
            }
        }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var hasDocument: Bool { sourceDocument != nil }

    var pageCount: Int { pages.count }

    func pageIndex(for id: UUID) -> Int? {
        pages.firstIndex(where: { $0.id == id })
    }

    // MARK: - Document search

    func openDocumentSearch() {
        documentSearch.isActive = true
    }

    func closeDocumentSearch() {
        documentSearch = DocumentSearchState()
        searchResultsCacheKey = nil
        searchResultsCache = nil
    }

    func updateDocumentSearchQuery(_ query: String) {
        documentSearch.results.query = query

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            documentSearch.results.matches = []
            documentSearch.currentMatchIndex = nil
            searchResultsCacheKey = nil
            searchResultsCache = nil
            return
        }

        guard let document = sourceDocument else {
            documentSearch.results.matches = []
            documentSearch.currentMatchIndex = nil
            return
        }

        let cacheKey = DocumentSearchEngine.cacheKey(query: query, document: document, pages: pages)
        let results: DocumentSearchResults
        if cacheKey == searchResultsCacheKey, let searchResultsCache {
            results = DocumentSearchResults(query: query, matches: searchResultsCache.matches)
        } else {
            results = DocumentSearchEngine.search(query: query, in: document, pages: pages)
            searchResultsCacheKey = cacheKey
            searchResultsCache = results
        }

        documentSearch.results = results
        reconcileCurrentSearchMatchIndex()
    }

    func selectDocumentSearchMatch(at globalIndex: Int) {
        guard documentSearch.results.matches.indices.contains(globalIndex) else { return }
        documentSearch.currentMatchIndex = globalIndex
    }

    @discardableResult
    func moveToNextDocumentSearchMatch() -> DocumentSearchMatch? {
        guard documentSearch.results.hasMatches else { return nil }
        let nextIndex = (documentSearch.currentMatchIndex ?? -1) + 1
        documentSearch.currentMatchIndex = nextIndex >= documentSearch.results.matchCount ? 0 : nextIndex
        return documentSearch.currentMatch
    }

    @discardableResult
    func moveToPreviousDocumentSearchMatch() -> DocumentSearchMatch? {
        guard documentSearch.results.hasMatches else { return nil }
        let count = documentSearch.results.matchCount
        let previousIndex = (documentSearch.currentMatchIndex ?? count) - 1
        documentSearch.currentMatchIndex = previousIndex < 0 ? count - 1 : previousIndex
        return documentSearch.currentMatch
    }

    func refreshDocumentSearchIfNeeded() {
        guard documentSearch.isActive,
              !documentSearch.results.isEmptyQuery else {
            return
        }
        let query = documentSearch.results.query
        searchResultsCacheKey = nil
        searchResultsCache = nil
        updateDocumentSearchQuery(query)
    }

    private func reconcileCurrentSearchMatchIndex() {
        guard documentSearch.results.hasMatches else {
            documentSearch.currentMatchIndex = nil
            return
        }

        if let currentMatchIndex = documentSearch.currentMatchIndex,
           documentSearch.results.matches.indices.contains(currentMatchIndex) {
            return
        }

        documentSearch.currentMatchIndex = 0
    }

    private func clearDocumentSearch() {
        closeDocumentSearch()
    }

    func importPDF(from url: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let imported = try pdfService.importPDF(from: url)
            sourceDocument = imported.document
            localSourceURL = imported.localURL
            documentName = imported.displayName
            pages = pdfService.makeInitialPages(pageCount: imported.pageCount)
            undoStack.removeAll()
            pageNumberSettings = .default
            watermarkSettings = .default
            clearOverlays()
            clearDocumentSearch()
            await ThumbnailService.shared.clear()
        } catch {
            resetDocument()
            errorMessage = error.localizedDescription
        }
    }

    private func importUITestDocument(pageCount: Int) async {
        do {
            let generatedURL = try UITestPDFGenerator.writeMultiPagePDF(pageCount: pageCount)
            await importPDF(from: generatedURL)

            if UITestLaunchConfiguration.shouldSeedOverlay,
               let firstPage = pages.first {
                addImageOverlay(
                    to: firstPage.id,
                    image: UIImage(systemName: "star.fill") ?? UIImage(),
                    pageAspectRatio: 612.0 / 792.0
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetDocument() {
        pages = []
        documentName = ""
        sourceDocument = nil
        localSourceURL = nil
        undoStack.removeAll()
        pageNumberSettings = .default
        watermarkSettings = .default
        errorMessage = nil
        clearOverlays()
        clearDocumentSearch()
    }

    /// Clears the current session and returns the app to the import empty state.
    func closeSession() async {
        if let localSourceURL {
            try? FileManager.default.removeItem(at: localSourceURL)
        }
        resetDocument()
        await ThumbnailService.shared.clear()
    }

    func recordUndoForDrag() {
        pushUndoSnapshot()
    }

    /// Reorders pages during drag-and-drop without pushing another undo entry.
    func reorderPage(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              pages.indices.contains(sourceIndex),
              destinationIndex >= 0,
              destinationIndex < pages.count else { return }

        let item = pages.remove(at: sourceIndex)
        pages.insert(item, at: destinationIndex)
        refreshDocumentSearchIfNeeded()
    }

    func deletePage(id: UUID) {
        guard let index = pageIndex(for: id) else { return }
        pushUndoSnapshot()
        pages.remove(at: index)
        removeOverlays(forPageItemID: id)
        removeAnnotations(forPageItemID: id)
        refreshDocumentSearchIfNeeded()
    }

    func rotatePage(id: UUID) {
        guard let index = pageIndex(for: id) else { return }
        pushUndoSnapshot()
        pages[index] = pages[index].rotated()
        bumpOverlayRevision(for: id)
    }

    func duplicatePage(id: UUID) {
        guard let index = pageIndex(for: id) else { return }
        pushUndoSnapshot()
        let duplicate = pages[index].duplicated()
        pages.insert(duplicate, at: index + 1)
        copyOverlays(fromPageItemID: id, toPageItemID: duplicate.id)
        copyAnnotations(fromPageItemID: id, toPageItemID: duplicate.id)
        refreshDocumentSearchIfNeeded()
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        pages = snapshot.pages
        pageObjectsByPage = snapshot.pageObjectsByPage
        annotationsByPage = snapshot.annotationsByPage
        overlayRevisions = snapshot.overlayRevisions
        imageAssets = snapshot.imageAssets
        pageNumberSettings = snapshot.pageNumberSettings
        watermarkSettings = snapshot.watermarkSettings
        refreshDocumentSearchIfNeeded()
        Task {
            await ThumbnailService.shared.clear()
        }
    }

    func exportPDF() throws -> URL {
        guard let sourceDocument else {
            throw PDFServiceError.exportFailed
        }
        return try pdfService.exportPDF(
            pages: pages,
            sourceDocument: sourceDocument,
            outputName: documentName.isEmpty ? "document" : documentName,
            overlaysByPage: pageObjectsByPage,
            annotationsByPage: annotationsByPage,
            imageAssets: imageAssets,
            pageNumberSettings: pageNumberSettings,
            watermarkSettings: watermarkSettings,
            watermarkImage: watermarkImage
        )
    }

    var watermarkImage: UIImage? {
        guard let assetID = watermarkSettings.imageAssetID else { return nil }
        return imageAssets[assetID]
    }

    func applyWatermark(_ settings: WatermarkSettings, watermarkImage newImage: UIImage? = nil) {
        pushUndoSnapshot()
        let previousAssetID = watermarkSettings.imageAssetID

        watermarkSettings = settings
        watermarkSettings.isEnabled = true

        switch watermarkSettings.watermarkType {
        case .text:
            watermarkSettings.imageAssetID = nil
        case .image:
            if let newImage {
                let assetID = UUID()
                imageAssets[assetID] = newImage
                watermarkSettings.imageAssetID = assetID
            }
        }

        if watermarkSettings.watermarkType == .image,
           watermarkSettings.imageAssetID == nil {
            watermarkSettings.isEnabled = false
        }

        if let previousAssetID,
           previousAssetID != watermarkSettings.imageAssetID,
           !isImageAssetReferenced(previousAssetID) {
            imageAssets.removeValue(forKey: previousAssetID)
        }

        Task {
            await ThumbnailService.shared.clear()
        }
    }

    func removeWatermark() {
        guard watermarkSettings.isEnabled else { return }
        pushUndoSnapshot()
        let orphanedAssetID = watermarkSettings.imageAssetID
        watermarkSettings = .default
        if let orphanedAssetID, !isImageAssetReferenced(orphanedAssetID) {
            imageAssets.removeValue(forKey: orphanedAssetID)
        }
        Task {
            await ThumbnailService.shared.clear()
        }
    }

    func applyPageNumbers(_ settings: PageNumberSettings) {
        pushUndoSnapshot()
        pageNumberSettings = settings
        pageNumberSettings.isEnabled = true
        Task {
            await ThumbnailService.shared.clear()
        }
    }

    func removePageNumbers() {
        guard pageNumberSettings.isEnabled else { return }
        pushUndoSnapshot()
        pageNumberSettings = .default
        Task {
            await ThumbnailService.shared.clear()
        }
    }

    func shouldShowPaywallForExport() -> Bool {
        proGate.requiresPaywall(pageCount: pages.count)
    }

    // MARK: - Compression

    func prepareCompressionInput() async throws -> CompressionPreparedInput {
        let exportURL = try exportPDF()
        let byteCount = fileByteCount(at: exportURL)
        return CompressionPreparedInput(exportURL: exportURL, byteCount: byteCount)
    }

    func compressPreparedPDF(
        _ input: CompressionPreparedInput,
        settings: CompressionSettings,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> CompressionResult {
        try await compressionService.compress(
            inputURL: input.exportURL,
            settings: settings,
            outputName: documentName.isEmpty ? "document" : documentName,
            progress: progress
        )
    }

    func cancelCompression() async {
        await compressionService.cancel()
    }

    func adoptCompressedPDF(from url: URL) async {
        await importPDF(from: url)
    }

    private func fileByteCount(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }

    // MARK: - Page overlays

    func overlayObjects(for pageItemID: UUID) -> [PageObject] {
        pageObjectsByPage[pageItemID] ?? []
    }

    func overlayRevision(for pageItemID: UUID) -> Int {
        overlayRevisions[pageItemID] ?? 0
    }

    func overlayImages(for pageItemID: UUID) -> [UUID: UIImage] {
        let objects = overlayObjects(for: pageItemID)
        var images: [UUID: UIImage] = [:]
        for object in objects {
            if let assetID = object.imageAssetID, let image = imageAssets[assetID] {
                images[assetID] = image
            }
        }
        return images
    }

    func imageAsset(for assetID: UUID) -> UIImage? {
        imageAssets[assetID]
    }

    @discardableResult
    func addTextOverlay(
        to pageItemID: UUID,
        draft: TextOverlayDraft,
        pageAspectRatio: CGFloat,
        at position: CGPoint
    ) -> UUID {
        pushUndoSnapshot()

        let storedText = TextOverlayFormattingEngine.displayText(
            draft.trimmedText,
            listMode: draft.listMode
        )
        let normalizedSize = TextOverlayLayoutEngine.measuredSize(
            text: storedText,
            fontSizePoints: draft.fontSizePoints,
            bold: draft.isBold,
            listMode: draft.listMode,
            pageAspectRatio: pageAspectRatio
        )

        let clampedPosition = OverlayInteractionEngine.clampNormalizedCenter(
            position,
            normalizedSize: normalizedSize
        )

        let nextZIndex = (pageObjectsByPage[pageItemID]?.map(\.zIndex).max() ?? -1) + 1
        let object = PageObject(
            pageItemID: pageItemID,
            type: .text,
            position: clampedPosition,
            size: normalizedSize,
            zIndex: nextZIndex,
            textContent: storedText,
            textFontSizePoints: TextOverlayLayoutEngine.clampedFontSize(draft.fontSizePoints),
            textColorRGBA: draft.colorRGBA,
            textBold: draft.isBold,
            textListMode: draft.listMode
        )

        pageObjectsByPage[pageItemID, default: []].append(object)
        bumpOverlayRevision(for: pageItemID)
        RecentTextsSettings.recordCommittedText(storedText)
        return object.id
    }

    func updateTextOverlay(
        id: UUID,
        pageItemID: UUID,
        draft: TextOverlayDraft
    ) -> Bool {
        guard var objects = pageObjectsByPage[pageItemID],
              let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].type == .text else {
            return false
        }

        let storedText = TextOverlayFormattingEngine.displayText(
            draft.trimmedText,
            listMode: draft.listMode
        )
        guard !storedText.isEmpty else { return false }

        pushUndoSnapshot()

        var object = objects[index]
        object.textContent = storedText
        object.textFontSizePoints = TextOverlayLayoutEngine.clampedFontSize(draft.fontSizePoints)
        object.textColorRGBA = draft.colorRGBA
        object.textBold = draft.isBold
        object.textListMode = draft.listMode

        objects[index] = object
        pageObjectsByPage[pageItemID] = objects
        bumpOverlayRevision(for: pageItemID)
        RecentTextsSettings.recordCommittedText(storedText)
        return true
    }

    @discardableResult
    func duplicateOverlay(id: UUID, pageItemID: UUID) -> UUID? {
        guard let objects = pageObjectsByPage[pageItemID],
              let source = objects.first(where: { $0.id == id }) else {
            return nil
        }

        pushUndoSnapshot()

        let offset = CGPoint(x: 0.03, y: 0.03)
        let nextZIndex = (objects.map(\.zIndex).max() ?? -1) + 1
        let duplicate = PageObject(
            pageItemID: pageItemID,
            type: source.type,
            position: OverlayInteractionEngine.clampNormalizedCenter(
                CGPoint(x: source.position.x + offset.x, y: source.position.y + offset.y),
                normalizedSize: source.size
            ),
            size: source.size,
            rotation: source.rotation,
            opacity: source.opacity,
            zIndex: nextZIndex,
            imageAssetID: source.imageAssetID,
            signatureLibrarySourceID: source.signatureLibrarySourceID,
            signatureSourceImageAssetID: source.signatureSourceImageAssetID,
            signatureInkColor: source.signatureInkColor,
            signatureCustomInkRGBA: source.signatureCustomInkRGBA,
            signatureStrokeWidthPoints: source.signatureStrokeWidthPoints,
            signatureBaselineInkColor: source.signatureBaselineInkColor,
            signatureBaselineStrokeThickness: source.signatureBaselineStrokeThickness,
            textContent: source.textContent,
            textFontSizePoints: source.textFontSizePoints,
            textColorRGBA: source.textColorRGBA,
            textBold: source.textBold,
            textListMode: source.textListMode
        )

        pageObjectsByPage[pageItemID, default: []].append(duplicate)
        bumpOverlayRevision(for: pageItemID)
        return duplicate.id
    }

    @discardableResult
    func addImageOverlay(to pageItemID: UUID, image: UIImage, pageAspectRatio: CGFloat) -> UUID {
        addRasterOverlay(
            to: pageItemID,
            image: image,
            type: .image,
            pageAspectRatio: pageAspectRatio,
            widthFraction: 0.35
        )
    }

    @discardableResult
    func addSignatureOverlay(
        to pageItemID: UUID,
        image: UIImage,
        pageAspectRatio: CGFloat,
        at position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        placementContext: SignaturePlacementContext? = nil
    ) -> UUID {
        let context = placementContext ?? SignaturePlacementContext(
            sourceImage: image,
            librarySourceID: nil,
            baselineInkColor: .defaultInk,
            baselineStrokeThickness: .defaultThickness
        )
        return addSignatureOverlay(
            to: pageItemID,
            context: context,
            pageAspectRatio: pageAspectRatio,
            at: position
        )
    }

    @discardableResult
    func addSignatureOverlay(
        to pageItemID: UUID,
        context: SignaturePlacementContext,
        pageAspectRatio: CGFloat,
        at position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> UUID {
        pushUndoSnapshot()

        let sourceAssetID = UUID()
        imageAssets[sourceAssetID] = context.sourceImage

        let displayAssetID = UUID()
        imageAssets[displayAssetID] = SignatureAppearanceEngine.renderDisplayImage(
            source: context.sourceImage,
            inkColor: context.baselineInkColor,
            thickness: context.baselineStrokeThickness,
            baselineThickness: context.baselineStrokeThickness
        )

        let normalizedSize = OverlayPlacementSizing.normalizedSignatureSize(
            image: context.sourceImage,
            pageAspectRatio: pageAspectRatio,
            widthFraction: 0.30
        )

        let nextZIndex = (pageObjectsByPage[pageItemID]?.map(\.zIndex).max() ?? -1) + 1
        let object = PageObject(
            pageItemID: pageItemID,
            type: .signature,
            position: position,
            size: normalizedSize,
            zIndex: nextZIndex,
            imageAssetID: displayAssetID,
            signatureLibrarySourceID: context.librarySourceID,
            signatureSourceImageAssetID: sourceAssetID,
            signatureInkColor: context.baselineInkColor,
            signatureStrokeThickness: context.baselineStrokeThickness,
            signatureBaselineInkColor: context.baselineInkColor,
            signatureBaselineStrokeThickness: context.baselineStrokeThickness
        )

        pageObjectsByPage[pageItemID, default: []].append(object)
        bumpOverlayRevision(for: pageItemID)
        return object.id
    }

    func updatePlacedSignatureAppearance(
        overlayID: UUID,
        pageItemID: UUID,
        presetInkColor: SignatureInkColor,
        customInkRGBA: SignatureInkRGBA?,
        strokeWidthPoints: Int
    ) {
        guard var objects = pageObjectsByPage[pageItemID],
              let index = objects.firstIndex(where: { $0.id == overlayID }) else {
            return
        }

        let object = objects[index]
        guard object.type == .signature,
              let sourceAssetID = object.signatureSourceImageAssetID ?? object.imageAssetID,
              let sourceImage = imageAssets[sourceAssetID],
              let displayAssetID = object.imageAssetID else {
            return
        }

        let clampedWidth = PlacedSignatureStrokeWidth.clamped(strokeWidthPoints)
        let baselineWidth = object.baselineSignatureStrokeWidthPoints

        let inkUIColor: UIColor
        if let customInkRGBA {
            inkUIColor = customInkRGBA.uiColor
        } else {
            inkUIColor = presetInkColor.uiColor
        }

        let rendered = SignatureAppearanceEngine.renderDisplayImage(
            source: sourceImage,
            inkColor: inkUIColor,
            strokeWidthPoints: clampedWidth,
            baselineStrokeWidthPoints: baselineWidth
        )

        let updated = PageObject(
            id: object.id,
            pageItemID: object.pageItemID,
            type: object.type,
            position: object.position,
            size: object.size,
            rotation: object.rotation,
            opacity: object.opacity,
            zIndex: object.zIndex,
            imageAssetID: object.imageAssetID,
            signatureLibrarySourceID: object.signatureLibrarySourceID,
            signatureSourceImageAssetID: object.signatureSourceImageAssetID,
            signatureInkColor: presetInkColor,
            signatureCustomInkRGBA: customInkRGBA,
            signatureStrokeWidthPoints: clampedWidth,
            signatureBaselineInkColor: object.signatureBaselineInkColor,
            signatureBaselineStrokeThickness: object.signatureBaselineStrokeThickness
        )

        guard objects[index] != updated else { return }

        pushUndoSnapshot()
        imageAssets[displayAssetID] = rendered
        objects[index] = updated
        pageObjectsByPage[pageItemID] = objects
        bumpOverlayRevision(for: pageItemID)
    }

    func updatePlacedSignatureAppearance(
        overlayID: UUID,
        pageItemID: UUID,
        inkColor: SignatureInkColor,
        strokeWidthPoints: Int
    ) {
        updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: pageItemID,
            presetInkColor: inkColor,
            customInkRGBA: nil,
            strokeWidthPoints: strokeWidthPoints
        )
    }

    func updatePlacedSignatureCustomColor(
        overlayID: UUID,
        pageItemID: UUID,
        color: UIColor,
        strokeWidthPoints: Int
    ) {
        guard let object = overlayObjects(for: pageItemID).first(where: { $0.id == overlayID }) else {
            return
        }

        updatePlacedSignatureAppearance(
            overlayID: overlayID,
            pageItemID: pageItemID,
            presetInkColor: object.effectiveSignatureInkColor,
            customInkRGBA: SignatureInkRGBA(uiColor: color),
            strokeWidthPoints: strokeWidthPoints
        )
    }

    func resetPlacedSignatureAppearance(overlayID: UUID, pageItemID: UUID) {
        guard var objects = pageObjectsByPage[pageItemID],
              let index = objects.firstIndex(where: { $0.id == overlayID }) else {
            return
        }

        let object = objects[index]
        guard object.type == .signature,
              let baselineColor = object.signatureBaselineInkColor,
              let sourceAssetID = object.signatureSourceImageAssetID ?? object.imageAssetID,
              let sourceImage = imageAssets[sourceAssetID],
              let displayAssetID = object.imageAssetID else {
            return
        }

        let baselineWidth = object.baselineSignatureStrokeWidthPoints
        let rendered = SignatureAppearanceEngine.renderDisplayImage(
            source: sourceImage,
            inkColor: baselineColor.uiColor,
            strokeWidthPoints: baselineWidth,
            baselineStrokeWidthPoints: baselineWidth
        )

        let updated = PageObject(
            id: object.id,
            pageItemID: object.pageItemID,
            type: object.type,
            position: object.position,
            size: object.size,
            rotation: object.rotation,
            opacity: object.opacity,
            zIndex: object.zIndex,
            imageAssetID: object.imageAssetID,
            signatureLibrarySourceID: object.signatureLibrarySourceID,
            signatureSourceImageAssetID: object.signatureSourceImageAssetID,
            signatureInkColor: nil,
            signatureCustomInkRGBA: nil,
            signatureStrokeWidthPoints: nil,
            signatureBaselineInkColor: object.signatureBaselineInkColor,
            signatureBaselineStrokeThickness: object.signatureBaselineStrokeThickness
        )

        guard objects[index] != updated else { return }

        pushUndoSnapshot()
        imageAssets[displayAssetID] = rendered
        objects[index] = updated
        pageObjectsByPage[pageItemID] = objects
        bumpOverlayRevision(for: pageItemID)
    }

    @discardableResult
    func savePlacedSignatureToLibrary(
        overlayID: UUID,
        pageItemID: UUID,
        store: SignatureLibraryStore
    ) throws -> SignatureAsset {
        guard let object = overlayObjects(for: pageItemID).first(where: { $0.id == overlayID }),
              object.type == .signature,
              object.canSavePlacedSignatureToLibrary,
              let displayAssetID = object.imageAssetID,
              let image = imageAssets[displayAssetID],
              let pngData = image.pngData() else {
            throw SignatureLibraryStoreError.invalidImageData
        }

        return try store.saveSignature(
            imageData: pngData,
            sourceType: .drawn,
            strokeThickness: object.effectiveSignatureStrokeThickness
        )
    }

    private func addRasterOverlay(
        to pageItemID: UUID,
        image: UIImage,
        type: PageObjectType,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> UUID {
        pushUndoSnapshot()

        let assetID = UUID()
        imageAssets[assetID] = image

        let normalizedSize: CGSize
        switch type {
        case .signature:
            normalizedSize = OverlayPlacementSizing.normalizedSignatureSize(
                image: image,
                pageAspectRatio: pageAspectRatio,
                widthFraction: widthFraction
            )
        case .image, .text:
            normalizedSize = OverlayPlacementSizing.normalizedImageSize(
                image: image,
                pageAspectRatio: pageAspectRatio,
                widthFraction: widthFraction
            )
        }

        let nextZIndex = (pageObjectsByPage[pageItemID]?.map(\.zIndex).max() ?? -1) + 1
        let object = PageObject(
            pageItemID: pageItemID,
            type: type,
            position: position,
            size: normalizedSize,
            zIndex: nextZIndex,
            imageAssetID: assetID
        )

        pageObjectsByPage[pageItemID, default: []].append(object)
        bumpOverlayRevision(for: pageItemID)
        return object.id
    }

    func updateOverlay(_ object: PageObject) {
        guard var objects = pageObjectsByPage[object.pageItemID],
              let index = objects.firstIndex(where: { $0.id == object.id }) else {
            return
        }
        guard objects[index] != object else { return }

        pushUndoSnapshot()
        objects[index] = object
        pageObjectsByPage[object.pageItemID] = objects
        bumpOverlayRevision(for: object.pageItemID)
    }

    func deleteOverlay(id: UUID, pageItemID: UUID) {
        guard var objects = pageObjectsByPage[pageItemID],
              objects.contains(where: { $0.id == id }) else { return }

        pushUndoSnapshot()

        if let object = objects.first(where: { $0.id == id }) {
            if let assetID = object.imageAssetID {
                releaseImageAssetIfUnreferenced(assetID, excludingObjectID: id)
            }
            if let sourceAssetID = object.signatureSourceImageAssetID {
                releaseImageAssetIfUnreferenced(sourceAssetID, excludingObjectID: id)
            }
        }

        objects.removeAll { $0.id == id }
        pageObjectsByPage[pageItemID] = objects
        bumpOverlayRevision(for: pageItemID)
    }

    // MARK: - Page annotations

    func annotations(for pageItemID: UUID) -> [PageAnnotation] {
        annotationsByPage[pageItemID] ?? []
    }

    @discardableResult
    func addHighlight(
        to pageItemID: UUID,
        normalizedRects: [PageNormalizedRect],
        selectedText: String,
        color: HighlightPresetColor = .defaultPreset,
        opacity: Double = Double(HighlightPresetColor.defaultOpacity)
    ) -> UUID? {
        guard !normalizedRects.isEmpty else { return nil }
        pushUndoSnapshot()

        let annotation = PageAnnotation(
            pageItemID: pageItemID,
            kind: .highlight,
            normalizedRects: normalizedRects,
            selectedText: selectedText,
            highlightColor: color,
            highlightOpacity: opacity
        )
        appendAnnotation(annotation, pageItemID: pageItemID)
        return annotation.id
    }

    func updateHighlightColor(id: UUID, pageItemID: UUID, color: HighlightPresetColor) -> Bool {
        guard var annotations = annotationsByPage[pageItemID],
              let index = annotations.firstIndex(where: { $0.id == id && $0.kind == .highlight }) else {
            return false
        }
        guard annotations[index].highlightColor != color else { return false }

        pushUndoSnapshot()
        annotations[index].highlightColor = color
        annotationsByPage[pageItemID] = annotations
        bumpOverlayRevision(for: pageItemID)
        return true
    }

    @discardableResult
    func addTextComment(
        to pageItemID: UUID,
        normalizedRects: [PageNormalizedRect],
        selectedText: String,
        commentText: String,
        linkedHighlightID: UUID? = nil
    ) -> UUID? {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !normalizedRects.isEmpty else { return nil }

        pushUndoSnapshot()
        let annotation = PageAnnotation(
            pageItemID: pageItemID,
            kind: .textComment,
            normalizedRects: normalizedRects,
            selectedText: selectedText,
            commentText: trimmed,
            linkedHighlightID: linkedHighlightID,
            anchorColorRGBA: TextCommentStyle.defaultAnchorColor
        )
        appendAnnotation(annotation, pageItemID: pageItemID)
        return annotation.id
    }

    func updateTextComment(id: UUID, pageItemID: UUID, commentText: String) -> Bool {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard var annotations = annotationsByPage[pageItemID],
              let index = annotations.firstIndex(where: { $0.id == id && $0.kind == .textComment }) else {
            return false
        }
        guard annotations[index].commentText != trimmed else { return false }

        pushUndoSnapshot()
        annotations[index].commentText = trimmed
        annotationsByPage[pageItemID] = annotations
        bumpOverlayRevision(for: pageItemID)
        return true
    }

    @discardableResult
    func addStickyNote(
        to pageItemID: UUID,
        normalizedPosition: PageNormalizedPoint,
        noteText: String
    ) -> UUID? {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        pushUndoSnapshot()
        let clamped = PageNormalizedPoint(
            AnnotationGeometryEngine.clampNormalizedPoint(normalizedPosition.cgPoint)
        )
        let annotation = PageAnnotation(
            pageItemID: pageItemID,
            kind: .stickyNote,
            normalizedPosition: clamped,
            noteText: trimmed,
            noteColorRGBA: StickyNoteStyle.defaultColor
        )
        appendAnnotation(annotation, pageItemID: pageItemID)
        return annotation.id
    }

    func updateStickyNote(id: UUID, pageItemID: UUID, noteText: String) -> Bool {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard var annotations = annotationsByPage[pageItemID],
              let index = annotations.firstIndex(where: { $0.id == id && $0.kind == .stickyNote }) else {
            return false
        }
        guard annotations[index].noteText != trimmed else { return false }

        pushUndoSnapshot()
        annotations[index].noteText = trimmed
        annotationsByPage[pageItemID] = annotations
        bumpOverlayRevision(for: pageItemID)
        return true
    }

    func moveStickyNote(id: UUID, pageItemID: UUID, normalizedPosition: PageNormalizedPoint) -> Bool {
        guard var annotations = annotationsByPage[pageItemID],
              let index = annotations.firstIndex(where: { $0.id == id && $0.kind == .stickyNote }) else {
            return false
        }

        let clamped = PageNormalizedPoint(
            AnnotationGeometryEngine.clampNormalizedPoint(normalizedPosition.cgPoint)
        )
        guard annotations[index].normalizedPosition != clamped else { return false }

        pushUndoSnapshot()
        annotations[index].normalizedPosition = clamped
        annotationsByPage[pageItemID] = annotations
        bumpOverlayRevision(for: pageItemID)
        return true
    }

    @discardableResult
    func addDrawingAnnotation(
        to pageItemID: UUID,
        strokes: [DrawingStroke]
    ) -> UUID? {
        guard !strokes.isEmpty else { return nil }
        pushUndoSnapshot()

        let annotation = PageAnnotation(
            pageItemID: pageItemID,
            kind: .drawing,
            strokes: strokes
        )
        appendAnnotation(annotation, pageItemID: pageItemID)
        return annotation.id
    }

    @discardableResult
    func replaceDrawingAnnotation(
        id: UUID,
        pageItemID: UUID,
        strokes: [DrawingStroke]
    ) -> Bool {
        guard !strokes.isEmpty else { return false }
        guard var annotations = annotationsByPage[pageItemID],
              let index = annotations.firstIndex(where: { $0.id == id && $0.kind == .drawing }) else {
            return false
        }

        pushUndoSnapshot()
        annotations[index].strokes = strokes
        annotationsByPage[pageItemID] = annotations
        bumpOverlayRevision(for: pageItemID)
        return true
    }

    func deleteAnnotation(id: UUID, pageItemID: UUID) {
        guard var annotations = annotationsByPage[pageItemID],
              annotations.contains(where: { $0.id == id }) else { return }

        pushUndoSnapshot()
        annotations.removeAll { $0.id == id }
        annotationsByPage[pageItemID] = annotations
        bumpOverlayRevision(for: pageItemID)
    }

    func annotation(id: UUID, pageItemID: UUID) -> PageAnnotation? {
        annotations(for: pageItemID).first { $0.id == id }
    }

    private func appendAnnotation(_ annotation: PageAnnotation, pageItemID: UUID) {
        annotationsByPage[pageItemID, default: []].append(annotation)
        bumpOverlayRevision(for: pageItemID)
    }

    private func bumpOverlayRevision(for pageItemID: UUID) {
        overlayRevisions[pageItemID, default: 0] += 1
    }

    private func copyOverlays(fromPageItemID sourceID: UUID, toPageItemID destinationID: UUID) {
        let sourceOverlays = pageObjectsByPage[sourceID] ?? []
        guard !sourceOverlays.isEmpty else { return }

        let copiedOverlays = sourceOverlays.map { overlay in
            PageObject(
                pageItemID: destinationID,
                type: overlay.type,
                position: overlay.position,
                size: overlay.size,
                rotation: overlay.rotation,
                opacity: overlay.opacity,
                zIndex: overlay.zIndex,
                imageAssetID: overlay.imageAssetID,
                signatureLibrarySourceID: overlay.signatureLibrarySourceID,
                signatureSourceImageAssetID: overlay.signatureSourceImageAssetID,
                signatureInkColor: overlay.signatureInkColor,
                signatureCustomInkRGBA: overlay.signatureCustomInkRGBA,
                signatureStrokeWidthPoints: overlay.signatureStrokeWidthPoints,
                signatureBaselineInkColor: overlay.signatureBaselineInkColor,
                signatureBaselineStrokeThickness: overlay.signatureBaselineStrokeThickness,
                textContent: overlay.textContent,
                textFontSizePoints: overlay.textFontSizePoints,
                textColorRGBA: overlay.textColorRGBA,
                textBold: overlay.textBold,
                textListMode: overlay.textListMode
            )
        }

        pageObjectsByPage[destinationID] = copiedOverlays
        bumpOverlayRevision(for: destinationID)
    }

    private func removeOverlays(forPageItemID pageItemID: UUID) {
        let objects = pageObjectsByPage[pageItemID] ?? []
        for object in objects {
            if let assetID = object.imageAssetID {
                releaseImageAssetIfUnreferenced(assetID, excludingObjectID: object.id)
            }
            if let sourceAssetID = object.signatureSourceImageAssetID {
                releaseImageAssetIfUnreferenced(sourceAssetID, excludingObjectID: object.id)
            }
        }
        pageObjectsByPage.removeValue(forKey: pageItemID)
        overlayRevisions.removeValue(forKey: pageItemID)
    }

    private func releaseImageAssetIfUnreferenced(_ assetID: UUID, excludingObjectID: UUID?) {
        guard !isImageAssetReferenced(assetID, excludingObjectID: excludingObjectID) else { return }
        imageAssets.removeValue(forKey: assetID)
    }

    private func isImageAssetReferenced(_ assetID: UUID, excludingObjectID: UUID? = nil) -> Bool {
        if watermarkSettings.imageAssetID == assetID {
            return true
        }
        for objects in pageObjectsByPage.values {
            for object in objects {
                if object.id == excludingObjectID { continue }
                if object.imageAssetID == assetID { return true }
                if object.signatureSourceImageAssetID == assetID { return true }
            }
        }
        return false
    }

    private func clearOverlays() {
        pageObjectsByPage.removeAll()
        annotationsByPage.removeAll()
        imageAssets.removeAll()
        overlayRevisions.removeAll()
    }

    private func removeAnnotations(forPageItemID pageItemID: UUID) {
        annotationsByPage.removeValue(forKey: pageItemID)
    }

    private func copyAnnotations(fromPageItemID sourceID: UUID, toPageItemID destinationID: UUID) {
        let sourceAnnotations = annotationsByPage[sourceID] ?? []
        guard !sourceAnnotations.isEmpty else { return }
        annotationsByPage[destinationID] = sourceAnnotations.map { $0.duplicated(forPageItemID: destinationID) }
        bumpOverlayRevision(for: destinationID)
    }

    private func pushUndoSnapshot() {
        undoStack.append(EditorSnapshot(
            pages: pages,
            pageObjectsByPage: pageObjectsByPage,
            annotationsByPage: annotationsByPage,
            overlayRevisions: overlayRevisions,
            imageAssets: imageAssets,
            pageNumberSettings: pageNumberSettings,
            watermarkSettings: watermarkSettings
        ))
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
