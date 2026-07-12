import SwiftUI
import UniformTypeIdentifiers

struct ScanDraftPageDropDelegate: DropDelegate {
    let destinationIndex: Int
    let viewModel: ScanDraftSessionViewModel
    @Binding var draggedPageID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggedPageID != nil && !viewModel.isMultiSelectionMode && !viewModel.isBatchProcessing
    }

    func dropEntered(info: DropInfo) {
        guard let draggedPageID,
              let document = viewModel.document,
              let sourceIndex = document.pages.firstIndex(where: { $0.id == draggedPageID }),
              sourceIndex != destinationIndex else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.reorderPages(from: sourceIndex, to: destinationIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageID = nil
        return true
    }
}
