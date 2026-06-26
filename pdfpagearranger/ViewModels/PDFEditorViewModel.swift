import Foundation
import PDFKit
import SwiftUI

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
    private let pdfService = PDFService()
    let proGate = ProGate()

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
            await ThumbnailService.shared.clear()
        } catch {
            resetDocument()
            errorMessage = error.localizedDescription
        }
    }

    func resetDocument() {
        pages = []
        documentName = ""
        sourceDocument = nil
        localSourceURL = nil
        undoStack.removeAll()
        errorMessage = nil
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
    }

    func rotatePage(id: UUID) {
        guard let index = pageIndex(for: id) else { return }
        pushUndoSnapshot()
        pages[index] = pages[index].rotated()
    }

    func duplicatePage(id: UUID) {
        guard let index = pageIndex(for: id) else { return }
        pushUndoSnapshot()
        let duplicate = pages[index].duplicated()
        pages.insert(duplicate, at: index + 1)
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        pages = snapshot.pages
    }

    func exportPDF() throws -> URL {
        guard let sourceDocument else {
            throw PDFServiceError.exportFailed
        }
        return try pdfService.exportPDF(
            pages: pages,
            sourceDocument: sourceDocument,
            outputName: documentName.isEmpty ? "document" : documentName
        )
    }

    func shouldShowPaywallForExport() -> Bool {
        proGate.requiresPaywall(pageCount: pages.count)
    }

    private func pushUndoSnapshot() {
        undoStack.append(EditorSnapshot(pages: pages))
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
}
