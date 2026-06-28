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
    @State private var showSignatureLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedObjectID: UUID?

    private let signatureLibraryStore: SignatureLibraryStore

    init(
        viewModel: PDFEditorViewModel,
        pageItem: PageItem,
        pageNumber: Int,
        document: PDFDocument,
        signatureLibraryStore: SignatureLibraryStore
    ) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.pageItem = pageItem
        self.pageNumber = pageNumber
        self.document = document
        self.signatureLibraryStore = signatureLibraryStore
    }

    init(
        viewModel: PDFEditorViewModel,
        pageItem: PageItem,
        pageNumber: Int,
        document: PDFDocument
    ) {
        self.init(
            viewModel: viewModel,
            pageItem: pageItem,
            pageNumber: pageNumber,
            document: document,
            signatureLibraryStore: Self.makeDefaultSignatureLibraryStore()
        )
    }

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pageModeView")
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
            PageAddOptionsSheet(
                onImageTapped: {
                    showPhotosPicker = true
                },
                onSignatureTapped: {
                    showSignatureLibrary = true
                }
            )
        }
        .sheet(isPresented: $showSignatureLibrary) {
            SignatureLibraryView(store: signatureLibraryStore) { image in
                viewModel.addSignatureOverlay(
                    to: pageItem.id,
                    image: image,
                    pageAspectRatio: pageAspectRatio
                )
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
                pageRotation: pageItem.rotation,
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
        .accessibilityIdentifier("pageModeAddButton")
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

    private static func makeDefaultSignatureLibraryStore() -> SignatureLibraryStore {
        if let uiTestRoot = UITestLaunchConfiguration.isolatedSignatureLibraryRoot {
            return SignatureLibraryStore(rootDirectory: uiTestRoot)
        }
        if let store = try? SignatureLibraryStore.makeDefault() {
            return store
        }
        let fallback = FileManager.default.temporaryDirectory
            .appendingPathComponent("SignatureLibrary", isDirectory: true)
        return SignatureLibraryStore(rootDirectory: fallback)
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
