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
    private var imageAssets: [UUID: UIImage] = [:]
    private var overlayRevisions: [UUID: Int] = [:]
    private(set) var pageNumberSettings: PageNumberSettings = .default
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
            clearOverlays()
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
        errorMessage = nil
        clearOverlays()
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
    }

    func deletePage(id: UUID) {
        guard let index = pageIndex(for: id) else { return }
        pushUndoSnapshot()
        pages.remove(at: index)
        removeOverlays(forPageItemID: id)
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
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        pages = snapshot.pages
        pageObjectsByPage = snapshot.pageObjectsByPage
        overlayRevisions = snapshot.overlayRevisions
        imageAssets = snapshot.imageAssets
        pageNumberSettings = snapshot.pageNumberSettings
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
            imageAssets: imageAssets,
            pageNumberSettings: pageNumberSettings
        )
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

    func addImageOverlay(to pageItemID: UUID, image: UIImage, pageAspectRatio: CGFloat) {
        addRasterOverlay(
            to: pageItemID,
            image: image,
            type: .image,
            pageAspectRatio: pageAspectRatio,
            widthFraction: 0.35
        )
    }

    func addSignatureOverlay(to pageItemID: UUID, image: UIImage, pageAspectRatio: CGFloat) {
        addRasterOverlay(
            to: pageItemID,
            image: image,
            type: .signature,
            pageAspectRatio: pageAspectRatio,
            widthFraction: 0.30
        )
    }

    private func addRasterOverlay(
        to pageItemID: UUID,
        image: UIImage,
        type: PageObjectType,
        pageAspectRatio: CGFloat,
        widthFraction: CGFloat
    ) {
        pushUndoSnapshot()

        let assetID = UUID()
        imageAssets[assetID] = image

        let imageAspect = image.size.width / max(image.size.height, 1)
        let heightFraction = min((widthFraction / imageAspect) / max(pageAspectRatio, 0.01), 0.6)

        let nextZIndex = (pageObjectsByPage[pageItemID]?.map(\.zIndex).max() ?? -1) + 1
        let object = PageObject(
            pageItemID: pageItemID,
            type: type,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: widthFraction, height: heightFraction),
            zIndex: nextZIndex,
            imageAssetID: assetID
        )

        pageObjectsByPage[pageItemID, default: []].append(object)
        bumpOverlayRevision(for: pageItemID)
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

        if let object = objects.first(where: { $0.id == id }),
           let assetID = object.imageAssetID,
           !isImageAssetReferenced(assetID, excludingObjectID: id) {
            imageAssets.removeValue(forKey: assetID)
        }

        objects.removeAll { $0.id == id }
        pageObjectsByPage[pageItemID] = objects
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
                imageAssetID: overlay.imageAssetID
            )
        }

        pageObjectsByPage[destinationID] = copiedOverlays
        bumpOverlayRevision(for: destinationID)
    }

    private func removeOverlays(forPageItemID pageItemID: UUID) {
        let objects = pageObjectsByPage[pageItemID] ?? []
        for object in objects {
            if let assetID = object.imageAssetID,
               !isImageAssetReferenced(assetID, excludingObjectID: object.id) {
                imageAssets.removeValue(forKey: assetID)
            }
        }
        pageObjectsByPage.removeValue(forKey: pageItemID)
        overlayRevisions.removeValue(forKey: pageItemID)
    }

    private func isImageAssetReferenced(_ assetID: UUID, excludingObjectID: UUID? = nil) -> Bool {
        for objects in pageObjectsByPage.values {
            for object in objects {
                if object.id == excludingObjectID { continue }
                if object.imageAssetID == assetID { return true }
            }
        }
        return false
    }

    private func clearOverlays() {
        pageObjectsByPage.removeAll()
        imageAssets.removeAll()
        overlayRevisions.removeAll()
    }

    private func pushUndoSnapshot() {
        undoStack.append(EditorSnapshot(
            pages: pages,
            pageObjectsByPage: pageObjectsByPage,
            overlayRevisions: overlayRevisions,
            imageAssets: imageAssets,
            pageNumberSettings: pageNumberSettings
        ))
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
