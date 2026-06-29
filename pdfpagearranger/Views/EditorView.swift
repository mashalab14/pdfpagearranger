import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Bindable var viewModel: PDFEditorViewModel

    @State private var showPaywall = false
    @State private var showShareSheet = false
    @State private var showCompression = false
    @State private var showPageNumbers = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var draggedPageID: UUID?
    @State private var dragUndoRecorded = false
    @State private var selectedPageRoute: PageEditorRoute?

    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        Group {
            if viewModel.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc",
                    description: Text("All pages were removed. Tap New PDF to import another document.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, item in
                            if let document = viewModel.sourceDocument {
                                pageCard(item: item, index: index, document: document)
                            }
                        }
                    }
                    .padding()
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("documentPageGrid")
            }
        }
        .navigationTitle(viewModel.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("New PDF") {
                    closeEditor()
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Undo") {
                    withAnimation { viewModel.undo() }
                }
                .disabled(!viewModel.canUndo)
                .accessibilityIdentifier("undoButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                DocumentActionsMenu(isEnabled: !viewModel.pages.isEmpty) { action in
                    switch action {
                    case .compress:
                        showCompression = true
                    case .pageNumbers:
                        showPageNumbers = true
                    case .export:
                        handleExportTap()
                    }
                }
            }
        }
        .sheet(isPresented: $showCompression) {
            CompressionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPageNumbers) {
            PageNumbersView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(pageCount: viewModel.pageCount) {
                viewModel.proGate.unlockForDevelopment()
                performExport()
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: cleanupExportFile) {
            if let exportURL {
                ShareSheet(items: [exportURL], accessibilityIdentifier: "exportShareSheet")
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .overlay {
            if showShareSheet {
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityIdentifier("exportShareSheet")
            }
        }
        .navigationDestination(item: $selectedPageRoute) { route in
            if let document = viewModel.sourceDocument,
               let index = viewModel.pageIndex(for: route.pageItemID),
               let item = viewModel.pages.first(where: { $0.id == route.pageItemID }) {
                PageEditorView(
                    viewModel: viewModel,
                    pageItem: item,
                    pageNumber: index + 1,
                    document: document
                )
            }
        }
    }

    @ViewBuilder
    private func pageCard(item: PageItem, index: Int, document: PDFDocument) -> some View {
        PageThumbnailView(
            item: item,
            pageNumber: index + 1,
            document: document,
            overlays: viewModel.overlayObjects(for: item.id),
            overlayImages: viewModel.overlayImages(for: item.id),
            overlayRevision: viewModel.overlayRevision(for: item.id),
            pageNumberSettings: viewModel.pageNumberSettings,
            exportIndex: index,
            totalPages: viewModel.pageCount,
            onRotate: { viewModel.rotatePage(id: item.id) },
            onDuplicate: { viewModel.duplicatePage(id: item.id) },
            onDelete: { viewModel.deletePage(id: item.id) },
            onTap: {
                selectedPageRoute = PageEditorRoute(pageItemID: item.id)
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

    private func closeEditor() {
        cleanupExportFile()
        showPaywall = false
        showShareSheet = false
        exportError = nil
        draggedPageID = nil
        dragUndoRecorded = false
        Task {
            await viewModel.closeSession()
        }
    }

    private func handleExportTap() {
        if viewModel.shouldShowPaywallForExport() {
            showPaywall = true
        } else {
            performExport()
        }
    }

    private func performExport() {
        do {
            let url = try viewModel.exportPDF()
            exportURL = url
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func cleanupExportFile() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }
        exportURL = nil
    }
}
