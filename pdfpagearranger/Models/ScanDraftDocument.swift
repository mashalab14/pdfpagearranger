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
        !removePages(ids: [id]).isEmpty
    }

    @discardableResult
    mutating func removePages(ids: Set<UUID>) -> Set<UUID> {
        guard !ids.isEmpty else { return [] }

        let removableIDs = ids.intersection(Set(pages.map(\.id)))
        guard !removableIDs.isEmpty else { return [] }

        let selectedIndex = selectedPageID.flatMap { id in
            pages.firstIndex(where: { $0.id == id })
        }

        pages.removeAll { removableIDs.contains($0.id) }
        selectedPageIDs.subtract(removableIDs)

        if let selectedPageID, removableIDs.contains(selectedPageID) {
            if pages.isEmpty {
                self.selectedPageID = nil
            } else if let selectedIndex {
                let fallbackIndex = min(selectedIndex, pages.count - 1)
                self.selectedPageID = pages[fallbackIndex].id
            } else {
                self.selectedPageID = pages.first?.id
            }
        }

        hasUnsavedChanges = true
        return removableIDs
    }

    mutating func insertDuplicatedPage(_ page: ScanDraftPage, after sourceID: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == sourceID }) else { return }
        pages.insert(page, at: index + 1)
        hasUnsavedChanges = true
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

    mutating func repairSelectionIfNeeded() {
        guard !pages.isEmpty else {
            selectedPageID = nil
            selectedPageIDs.removeAll()
            return
        }

        if let selectedPageID,
           pages.contains(where: { $0.id == selectedPageID }) {
            return
        }

        selectPage(id: pages.first?.id)
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
