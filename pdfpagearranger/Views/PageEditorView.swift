import PDFKit
import PhotosUI
import SwiftUI

struct PageEditorRoute: Hashable {
    let pageItemID: UUID
}

struct PageEditorView: View {
    @Bindable var viewModel: PDFEditorViewModel

    let pageItem: PageItem
    let pageNumber: Int
    let document: PDFDocument

    @Environment(\.dismiss) private var dismiss
    @State private var pageImage: UIImage?
    @State private var showAddSheet = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedObjectID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            addButtonBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Page \(pageNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
            if selectedObjectID != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete", role: .destructive) {
                        deleteSelectedOverlay()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PageAddOptionsSheet {
                showPhotosPicker = true
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await importPhotoItem(newItem)
            }
        }
        .task(id: renderTaskKey) {
            await loadPageImage()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if let pageImage {
            PageOverlayCanvasView(
                pageImage: pageImage,
                objects: viewModel.overlayObjects(for: pageItem.id),
                selectedObjectID: $selectedObjectID,
                imageProvider: { viewModel.imageAsset(for: $0) },
                onUpdate: { viewModel.updateOverlay($0) },
                onDelete: { viewModel.deleteOverlay(id: $0, pageItemID: pageItem.id) }
            )
            .padding()
        } else {
            ProgressView("Loading page…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var addButtonBar: some View {
        HStack {
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var renderTaskKey: String {
        "\(pageItem.id.uuidString)-\(pageItem.rotation)"
    }

    private var pageAspectRatio: CGFloat {
        guard let page = document.page(at: pageItem.originalPageIndex) else {
            return 8.5 / 11.0
        }
        let bounds = page.bounds(for: .mediaBox)
        return bounds.width / max(bounds.height, 1)
    }

    private func loadPageImage() async {
        pageImage = await PageRenderService.shared.pageImage(for: pageItem, document: document)
    }

    private func importPhotoItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        viewModel.addImageOverlay(
            to: pageItem.id,
            image: image,
            pageAspectRatio: pageAspectRatio
        )
        selectedPhotoItem = nil
    }

    private func deleteSelectedOverlay() {
        guard let selectedObjectID else { return }
        viewModel.deleteOverlay(id: selectedObjectID, pageItemID: pageItem.id)
        self.selectedObjectID = nil
    }
}

#Preview {
    NavigationStack {
        PageEditorView(
            viewModel: PDFEditorViewModel(),
            pageItem: PageItem(originalPageIndex: 0),
            pageNumber: 1,
            document: PDFDocument()
        )
    }
}
