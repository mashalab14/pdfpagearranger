import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Bindable var viewModel: PDFEditorViewModel

    @State private var showPaywall = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var draggedPageID: UUID?

    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        Group {
            if viewModel.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc",
                    description: Text("All pages were removed. Import a new PDF to continue.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, item in
                            if let document = viewModel.sourceDocument {
                                PageThumbnailView(
                                    item: item,
                                    pageNumber: index + 1,
                                    document: document,
                                    onRotate: { viewModel.rotatePage(at: index) },
                                    onDuplicate: { viewModel.duplicatePage(at: index) },
                                    onDelete: { viewModel.deletePage(at: index) }
                                )
                                .opacity(draggedPageID == item.id ? 0.4 : 1)
                                .draggable(item.id.uuidString) {
                                    dragPreview(for: item, pageNumber: index + 1, document: document)
                                }
                                .dropDestination(for: String.self) { droppedIDs, location in
                                    guard let droppedID = droppedIDs.first,
                                          let droppedUUID = UUID(uuidString: droppedID),
                                          let sourceIndex = viewModel.pages.firstIndex(where: { $0.id == droppedUUID }),
                                          sourceIndex != index else {
                                        return false
                                    }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.movePage(from: sourceIndex, to: index)
                                    }
                                    draggedPageID = nil
                                    return true
                                } isTargeted: { isTargeted in
                                    if isTargeted {
                                        draggedPageID = item.id
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(viewModel.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Undo") {
                    withAnimation { viewModel.undo() }
                }
                .disabled(!viewModel.canUndo)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export") {
                    handleExportTap()
                }
                .disabled(viewModel.pages.isEmpty)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(pageCount: viewModel.pageCount) {
                viewModel.proGate.unlockForDevelopment()
                performExport()
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: cleanupExportFile) {
            if let exportURL {
                ShareSheet(items: [exportURL])
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

    @ViewBuilder
    private func dragPreview(for item: PageItem, pageNumber: Int, document: PDFDocument) -> some View {
        VStack {
            Text("Page \(pageNumber)")
                .font(.caption.bold())
            Image(systemName: "doc.fill")
                .font(.largeTitle)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear { draggedPageID = item.id }
        .onDisappear { draggedPageID = nil }
    }
}
