import Foundation

/// One unfinished scan-to-PDF session shared by Camera and Photos input paths.
struct ScanDraftDocument: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var pages: [ScanDraftPage]
    let createdAt: Date
    var selectedPageID: UUID?
    var selectedPageIDs: Set<UUID>
    var processingStatus: ScanDocumentProcessingStatus
    var generatedPDFURL: URL?
    var sessionDefaultVisualAdjustments: ScanVisualAdjustments
    var hasUnsavedChanges: Bool

    init(
        id: UUID = UUID(),
        pages: [ScanDraftPage] = [],
        createdAt: Date = Date(),
        selectedPageID: UUID? = nil,
        selectedPageIDs: Set<UUID> = [],
        processingStatus: ScanDocumentProcessingStatus = .idle,
        generatedPDFURL: URL? = nil,
        sessionDefaultVisualAdjustments: ScanVisualAdjustments = .neutral,
        hasUnsavedChanges: Bool = false
    ) {
        self.id = id
        self.pages = pages
        self.createdAt = createdAt
        self.selectedPageID = selectedPageID
        self.selectedPageIDs = selectedPageIDs
        self.processingStatus = processingStatus
        self.generatedPDFURL = generatedPDFURL
        self.sessionDefaultVisualAdjustments = sessionDefaultVisualAdjustments
        self.hasUnsavedChanges = hasUnsavedChanges
    }

    var isEmpty: Bool { pages.isEmpty }

    var currentPage: ScanDraftPage? {
        guard let selectedPageID else { return pages.first }
        return pages.first(where: { $0.id == selectedPageID })
    }

    mutating func addPage(_ page: ScanDraftPage) {
        pages.append(page)
        if selectedPageID == nil {
            selectedPageID = page.id
        }
        hasUnsavedChanges = true
    }

    mutating func addPages(_ newPages: [ScanDraftPage]) {
        guard !newPages.isEmpty else { return }
        pages.append(contentsOf: newPages)
        if selectedPageID == nil {
            selectedPageID = newPages.first?.id
        }
        hasUnsavedChanges = true
    }

    @discardableResult
    mutating func removePage(id: UUID) -> Bool {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return false }

        pages.remove(at: index)
        selectedPageIDs.remove(id)

        if selectedPageID == id {
            if pages.isEmpty {
                selectedPageID = nil
            } else {
                let fallbackIndex = min(index, pages.count - 1)
                selectedPageID = pages[fallbackIndex].id
            }
        }

        hasUnsavedChanges = true
        return true
    }

    mutating func reorderPages(from source: Int, to destination: Int) {
        guard source != destination,
              pages.indices.contains(source),
              destination >= 0,
              destination < pages.count else {
            return
        }

        let page = pages.remove(at: source)
        pages.insert(page, at: destination)
        hasUnsavedChanges = true
    }

    mutating func updatePage(id: UUID, _ update: (inout ScanDraftPage) -> Void) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        update(&pages[index])
        hasUnsavedChanges = true
    }

    mutating func selectPage(id: UUID?) {
        selectedPageID = id
        if let id {
            selectedPageIDs = [id]
        } else {
            selectedPageIDs.removeAll()
        }
    }

    mutating func setMultiSelection(_ pageIDs: Set<UUID>) {
        selectedPageIDs = pageIDs
        if pageIDs.count == 1 {
            selectedPageID = pageIDs.first
        }
    }

    mutating func applyVisualAdjustments(_ adjustments: ScanVisualAdjustments, toPageIDs: Set<UUID>) {
        guard !toPageIDs.isEmpty else { return }
        let copied = adjustments.copied()
        for index in pages.indices where toPageIDs.contains(pages[index].id) {
            pages[index].visualAdjustments = copied
            clearProcessingOutput(for: index)
        }
        hasUnsavedChanges = true
    }

    mutating func applyVisualAdjustmentsToAll(_ adjustments: ScanVisualAdjustments) {
        let copied = adjustments.copied()
        for index in pages.indices {
            pages[index].visualAdjustments = copied
            clearProcessingOutput(for: index)
        }
        sessionDefaultVisualAdjustments = copied
        hasUnsavedChanges = true
    }

    mutating func rotatePage(id: UUID) {
        updatePage(id: id) { page in
            page.geometry = page.geometry.rotated()
            page.processingState = .pending
            page.processingError = nil
            page.processingFingerprint = nil
            page.processedImage = nil
            page.thumbnailState = .notGenerated
            page.thumbnailImage = nil
        }
    }

    private mutating func clearProcessingOutput(for index: Int) {
        pages[index].processingState = .pending
        pages[index].processingError = nil
        pages[index].processingFingerprint = nil
        pages[index].processedImage = nil
        pages[index].thumbnailState = .notGenerated
        pages[index].thumbnailImage = nil
    }
}
