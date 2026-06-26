import SwiftUI
import UniformTypeIdentifiers

struct PageDropDelegate: DropDelegate {
    let destinationIndex: Int
    let viewModel: PDFEditorViewModel
    @Binding var draggedPageID: UUID?
    @Binding var dragUndoRecorded: Bool

    func validateDrop(info: DropInfo) -> Bool {
        draggedPageID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedPageID,
              let sourceIndex = viewModel.pages.firstIndex(where: { $0.id == draggedPageID }),
              sourceIndex != destinationIndex else {
            return
        }

        if !dragUndoRecorded {
            viewModel.recordUndoForDrag()
            dragUndoRecorded = true
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.reorderPage(from: sourceIndex, to: destinationIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPageID = nil
        dragUndoRecorded = false
        return true
    }
}
