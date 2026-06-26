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
    var hasDocument: Bool { sourceDocument != nil && !pages.isEmpty }

    var pageCount: Int { pages.count }

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
    }

    func movePage(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else { return }
        pushUndoSnapshot()
        pages.move(fromOffsets: source, toOffset: destination)
    }

    func movePage(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              pages.indices.contains(sourceIndex),
              destinationIndex >= 0,
              destinationIndex <= pages.count else { return }

        pushUndoSnapshot()
        let item = pages.remove(at: sourceIndex)
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        pages.insert(item, at: min(adjustedDestination, pages.count))
    }

    func deletePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pushUndoSnapshot()
        pages.remove(at: index)
    }

    func rotatePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pushUndoSnapshot()
        pages[index] = pages[index].rotated()
    }

    func duplicatePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
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
