import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Thumbnail grid used to reorder and manage pages without leaving the unified document editor.
struct DocumentPagesOrganizerSheet: View {
    @Bindable var viewModel: PDFEditorViewModel
    let document: PDFDocument
    let onSelectPage: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var draggedPageID: UUID?
    @State private var dragUndoRecorded = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, item in
                        pageCard(item: item, index: index)
                    }
                }
                .padding()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("documentPageGrid")
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    @ViewBuilder
    private func pageCard(item: PageItem, index: Int) -> some View {
        PageThumbnailView(
            item: item,
            pageNumber: index + 1,
            document: document,
            overlays: viewModel.overlayObjects(for: item.id),
            overlayImages: viewModel.overlayImages(for: item.id),
            annotations: viewModel.annotations(for: item.id),
            overlayRevision: viewModel.overlayRevision(for: item.id),
            pageNumberSettings: viewModel.pageNumberSettings,
            watermarkSettings: viewModel.watermarkSettings,
            watermarkImage: viewModel.watermarkImage,
            exportIndex: index,
            totalPages: viewModel.pageCount,
            onRotate: { viewModel.rotatePage(id: item.id) },
            onDuplicate: { viewModel.duplicatePage(id: item.id) },
            onDelete: { viewModel.deletePage(id: item.id) },
            onTap: {
                onSelectPage(item.id)
                onDismiss()
            }
        )
        .opacity(draggedPageID == item.id ? 0.5 : 1)
        .onDrag {
            draggedPageID = item.id
            dragUndoRecorded = false
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: PageDropDelegate(
                destinationIndex: index,
                viewModel: viewModel,
                draggedPageID: $draggedPageID,
                dragUndoRecorded: $dragUndoRecorded
            )
        )
    }
}
