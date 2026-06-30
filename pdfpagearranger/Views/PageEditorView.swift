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
    @State private var pageSelection: PageModeSelection = .none
    @State private var pdfSelectionClearToken = UUID()
    @State private var placementAnimatingOverlayIDs: Set<UUID> = []
    @State private var pendingSignaturePlacement: SignaturePlacementContext?
    @State private var pageTransitionEdge: Edge = .trailing
    @State private var lastPageNavigationUptime: TimeInterval = 0
    @State private var editingSignatureOverlayID: UUID?

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

    private var signaturePlacementActive: Bool {
        pendingSignaturePlacement != nil
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
            if pageSelection.selectedOverlayID != nil, !signaturePlacementActive {
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
                    clearPDFTextSelection()
                    showPhotosPicker = true
                },
                onQuickSignatureTapped: {
                    clearPDFTextSelection()
                    handleQuickSignature()
                },
                onSignatureLibraryTapped: {
                    clearPDFTextSelection()
                    signatureLibraryShowsDefaultGuidance = false
                    showSignatureLibrary = true
                }
            )
        }
        .sheet(isPresented: $showSignatureLibrary) {
            SignatureLibraryView(
                store: signatureLibraryStore,
                showDefaultGuidanceBanner: signatureLibraryShowsDefaultGuidance
            ) { context in
                beginSignaturePlacement(context: context)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingSignatureOverlayID != nil },
            set: { isPresented in
                if !isPresented {
                    editingSignatureOverlayID = nil
                }
            }
        )) {
            if let pageItem,
               let overlayID = editingSignatureOverlayID,
               let overlay = viewModel.overlayObjects(for: pageItem.id).first(where: { $0.id == overlayID }) {
                EditPlacedSignatureSheet(
                    overlayID: overlayID,
                    pageItemID: pageItem.id,
                    overlay: overlay,
                    viewModel: viewModel,
                    libraryStore: signatureLibraryStore
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
        .onChange(of: showAddSheet) { _, isPresented in
            if isPresented {
                cancelSignaturePlacement()
                clearPDFTextSelection()
                pageSelection = .none
                editingSignatureOverlayID = nil
            }
        }
        .onChange(of: pageRoute.pageItemID) { _, _ in
            cancelSignaturePlacement()
            editingSignatureOverlayID = nil
            pageSelection = .none
            bumpPDFSelectionClearToken()
            placementAnimatingOverlayIDs.removeAll()
        }
        .onChange(of: pageSelection) { oldValue, newValue in
            if case .pdfText = oldValue, newValue.pdfTextSelection == nil {
                bumpPDFSelectionClearToken()
            }
        }
        .task(id: renderTaskKey) {
            await loadPageImage()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if let pageImage, let pageItem, let pdfPage = document.page(at: pageItem.originalPageIndex) {
            PageOverlayCanvasView(
                pageImage: pageImage,
                pdfPage: pdfPage,
                pageRotation: pageItem.rotation,
                pageLoadKey: "\(pageItem.id.uuidString)-\(pageItem.rotation)",
                objects: viewModel.overlayObjects(for: pageItem.id),
                placementAnimatingOverlayIDs: placementAnimatingOverlayIDs,
                onPlacementAnimationFinished: { overlayID in
                    placementAnimatingOverlayIDs.remove(overlayID)
                },
                signaturePlacementActive: signaturePlacementActive,
                onSignaturePlacementTap: { location, displaySize in
                    placeSignature(atDisplayTap: location, displayPageSize: displaySize)
                },
                onSignaturePlacementDismiss: {
                    cancelSignaturePlacement()
                },
                pageSelection: $pageSelection,
                pdfSelectionClearToken: pdfSelectionClearToken,
                imageProvider: { viewModel.imageAsset(for: $0) },
                onUpdate: { viewModel.updateOverlay($0) },
                onDelete: { viewModel.deleteOverlay(id: $0, pageItemID: pageItem.id) },
                onPageSwipe: { direction in
                    navigateToAdjacentPage(direction: direction)
                },
                onPDFTextMenuCopy: copySelectedPDFText,
                onEditSignature: { overlayID in
                    editingSignatureOverlayID = overlayID
                },
                pageTransitionEdge: pageTransitionEdge
            )
        } else {
            ProgressView("Loading page…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var addButtonBar: some View {
        HStack {
            Spacer()
            Button {
                clearPDFTextSelection()
                pageSelection = .none
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
        return "\(pageItem.id.uuidString)-\(pageItem.rotation)-\(viewModel.pageNumberSettings.thumbnailCacheKeySuffix)-\(viewModel.watermarkSettings.thumbnailCacheKeySuffix)-\(exportIndex)-\(viewModel.pageCount)"
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
        let pageID = pageItem.id
        let exportIndex = viewModel.pageIndex(for: pageID) ?? (pageNumber - 1)
        let image = await PageRenderService.shared.pageImage(
            for: pageItem,
            document: document,
            pageNumberSettings: viewModel.pageNumberSettings,
            watermarkSettings: viewModel.watermarkSettings,
            watermarkImage: viewModel.watermarkImage,
            exportIndex: exportIndex,
            totalPages: viewModel.pageCount
        )
        guard self.pageItem?.id == pageID else { return }
        pageImage = image
    }

    private func importPhotoItem(_ item: PhotosPickerItem) async {
        guard let pageItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        let overlayID = viewModel.addImageOverlay(
            to: pageItem.id,
            image: image,
            pageAspectRatio: pageAspectRatio
        )
        selectedPhotoItem = nil
        registerNewOverlayPlacement(overlayID: overlayID)
    }

    private func deleteSelectedOverlay() {
        guard let pageItem, let overlayID = pageSelection.selectedOverlayID else { return }
        editingSignatureOverlayID = nil
        viewModel.deleteOverlay(id: overlayID, pageItemID: pageItem.id)
        pageSelection = .none
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
            beginSignaturePlacement(
                context: SignaturePlacementContext.fromLibraryAsset(asset, image: image)
            )
        case .openLibrary(let showDefaultGuidanceBanner):
            signatureLibraryShowsDefaultGuidance = showDefaultGuidanceBanner
            showSignatureLibrary = true
        }
    }

    private func beginSignaturePlacement(context: SignaturePlacementContext) {
        clearPDFTextSelection()
        editingSignatureOverlayID = nil
        pendingSignaturePlacement = context
        pageSelection = .none
    }

    private func cancelSignaturePlacement() {
        pendingSignaturePlacement = nil
    }

    private func placeSignature(atDisplayTap tap: CGPoint, displayPageSize: CGSize) {
        guard let pageItem, let context = pendingSignaturePlacement else { return }
        guard SignaturePlacementEngine.isDisplayTapInsidePage(tap, displayPageSize: displayPageSize) else {
            return
        }

        let normalizedSize = OverlayPlacementSizing.normalizedSignatureSize(
            image: context.sourceImage,
            pageAspectRatio: pageAspectRatio
        )
        let position = SignaturePlacementEngine.storagePosition(
            forDisplayTap: tap,
            displayPageSize: displayPageSize,
            normalizedOverlaySize: normalizedSize,
            pageRotation: pageItem.rotation
        )

        pendingSignaturePlacement = nil

        let overlayID = viewModel.addSignatureOverlay(
            to: pageItem.id,
            context: context,
            pageAspectRatio: pageAspectRatio,
            at: position
        )
        registerNewOverlayPlacement(overlayID: overlayID)
    }

    private func copySelectedPDFText(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func clearPDFTextSelection() {
        if case .pdfText = pageSelection {
            pageSelection = .none
        }
        bumpPDFSelectionClearToken()
    }

    private func bumpPDFSelectionClearToken() {
        pdfSelectionClearToken = UUID()
    }

    private func registerNewOverlayPlacement(overlayID: UUID) {
        placementAnimatingOverlayIDs.insert(overlayID)
        OverlayPlacementFeedback.playPlacementHaptic()
        pageSelection = .overlay(overlayID)
    }

    private func navigateToAdjacentPage(direction: PageModeNavigationDirection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPageNavigationUptime > 0.35 else { return }

        guard let currentIndex = viewModel.pageIndex(for: pageRoute.pageItemID),
              let targetIndex = PageModeNavigationEngine.adjacentPageIndex(
                currentIndex: currentIndex,
                pageCount: viewModel.pageCount,
                direction: direction
              ) else {
            return
        }

        lastPageNavigationUptime = now
        pageSelection = .none
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
