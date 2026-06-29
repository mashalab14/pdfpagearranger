import PDFKit
import PhotosUI
import SwiftUI

struct PageEditorRoute: Hashable {
    let pageItemID: UUID
}

struct PageEditorView: View {
    @Bindable var viewModel: PDFEditorViewModel
    @Binding var pageRoute: PageEditorRoute

    let document: PDFDocument

    @Environment(\.dismiss) private var dismiss
    @State private var pageImage: UIImage?
    @State private var showAddSheet = false
    @State private var showPhotosPicker = false
    @State private var showSignatureLibrary = false
    @State private var signatureLibraryShowsDefaultGuidance = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedObjectID: UUID?
    @State private var pageTransitionEdge: Edge = .trailing

    private let signatureLibraryStore: SignatureLibraryStore

    init(
        viewModel: PDFEditorViewModel,
        pageRoute: Binding<PageEditorRoute>,
        document: PDFDocument,
        signatureLibraryStore: SignatureLibraryStore
    ) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        self._pageRoute = pageRoute
        self.document = document
        self.signatureLibraryStore = signatureLibraryStore
    }

    init(
        viewModel: PDFEditorViewModel,
        pageRoute: Binding<PageEditorRoute>,
        document: PDFDocument
    ) {
        self.init(
            viewModel: viewModel,
            pageRoute: pageRoute,
            document: document,
            signatureLibraryStore: Self.makeDefaultSignatureLibraryStore()
        )
    }

    private var pageItem: PageItem? {
        viewModel.pages.first(where: { $0.id == pageRoute.pageItemID })
    }

    private var pageNumber: Int {
        (viewModel.pageIndex(for: pageRoute.pageItemID) ?? 0) + 1
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
        .accessibilityValue("page \(pageNumber) of \(viewModel.pageCount)")
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
                onQuickSignatureTapped: {
                    handleQuickSignature()
                },
                onSignatureLibraryTapped: {
                    signatureLibraryShowsDefaultGuidance = false
                    showSignatureLibrary = true
                }
            )
        }
        .sheet(isPresented: $showSignatureLibrary) {
            SignatureLibraryView(
                store: signatureLibraryStore,
                showDefaultGuidanceBanner: signatureLibraryShowsDefaultGuidance
            ) { image in
                placeSignature(image: image)
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await importPhotoItem(newItem)
            }
        }
        .onChange(of: pageRoute.pageItemID) { _, _ in
            selectedObjectID = nil
        }
        .task(id: renderTaskKey) {
            await loadPageImage()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if let pageImage, let pageItem {
            PageOverlayCanvasView(
                pageImage: pageImage,
                pageRotation: pageItem.rotation,
                objects: viewModel.overlayObjects(for: pageItem.id),
                selectedObjectID: $selectedObjectID,
                imageProvider: { viewModel.imageAsset(for: $0) },
                onUpdate: { viewModel.updateOverlay($0) },
                onDelete: { viewModel.deleteOverlay(id: $0, pageItemID: pageItem.id) },
                onPageSwipe: { direction in
                    navigateToAdjacentPage(direction: direction)
                }
            )
            .padding()
            .id(pageItem.id)
            .transition(.asymmetric(
                insertion: .move(edge: pageTransitionEdge),
                removal: .move(edge: pageTransitionEdge == .trailing ? .leading : .trailing)
            ))
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
        guard let pageItem else { return "missing-page" }
        let exportIndex = viewModel.pageIndex(for: pageItem.id) ?? (pageNumber - 1)
        return "\(pageItem.id.uuidString)-\(pageItem.rotation)-\(viewModel.pageNumberSettings.thumbnailCacheKeySuffix)-\(exportIndex)-\(viewModel.pageCount)"
    }

    private var pageAspectRatio: CGFloat {
        guard let pageItem,
              let page = document.page(at: pageItem.originalPageIndex) else {
            return 8.5 / 11.0
        }
        let bounds = page.bounds(for: .mediaBox)
        return bounds.width / max(bounds.height, 1)
    }

    private func loadPageImage() async {
        guard let pageItem else { return }
        let exportIndex = viewModel.pageIndex(for: pageItem.id) ?? (pageNumber - 1)
        pageImage = await PageRenderService.shared.pageImage(
            for: pageItem,
            document: document,
            pageNumberSettings: viewModel.pageNumberSettings,
            exportIndex: exportIndex,
            totalPages: viewModel.pageCount
        )
    }

    private func importPhotoItem(_ item: PhotosPickerItem) async {
        guard let pageItem,
              let data = try? await item.loadTransferable(type: Data.self),
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
        guard let pageItem, let selectedObjectID else { return }
        viewModel.deleteOverlay(id: selectedObjectID, pageItemID: pageItem.id)
        self.selectedObjectID = nil
    }

    private func handleQuickSignature() {
        switch signatureLibraryStore.resolveQuickSignatureResolution() {
        case .placeImmediately(let asset):
            guard let data = signatureLibraryStore.loadImageData(for: asset),
                  let image = UIImage(data: data) else {
                signatureLibraryShowsDefaultGuidance = false
                showSignatureLibrary = true
                return
            }
            placeSignature(image: image)
        case .openLibrary(let showDefaultGuidanceBanner):
            signatureLibraryShowsDefaultGuidance = showDefaultGuidanceBanner
            showSignatureLibrary = true
        }
    }

    private func placeSignature(image: UIImage) {
        guard let pageItem else { return }
        let overlayID = viewModel.addSignatureOverlay(
            to: pageItem.id,
            image: image,
            pageAspectRatio: pageAspectRatio
        )
        selectedObjectID = overlayID
    }

    private func navigateToAdjacentPage(direction: PageModeNavigationDirection) {
        guard let currentIndex = viewModel.pageIndex(for: pageRoute.pageItemID),
              let targetIndex = PageModeNavigationEngine.adjacentPageIndex(
                currentIndex: currentIndex,
                pageCount: viewModel.pageCount,
                direction: direction
              ) else {
            return
        }

        selectedObjectID = nil
        pageTransitionEdge = direction == .next ? .trailing : .leading

        withAnimation(.easeInOut(duration: 0.25)) {
            pageRoute = PageEditorRoute(pageItemID: viewModel.pages[targetIndex].id)
        }
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
            pageRoute: .constant(PageEditorRoute(pageItemID: PageItem(originalPageIndex: 0).id)),
            document: PDFDocument()
        )
    }
}
