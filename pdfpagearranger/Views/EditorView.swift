import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Bindable var viewModel: PDFEditorViewModel

    @State private var showPaywall = false
    @State private var showShareSheet = false
    @State private var showCompression = false
    @State private var showPageNumbers = false
    @State private var showWatermark = false
    @State private var showPagesOrganizer = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var activePageRoute: PageEditorRoute?

    var body: some View {
        Group {
            if viewModel.pages.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "doc",
                    description: Text("All pages were removed. Tap New PDF to import another document.")
                )
                .toolbar { emptyDocumentToolbar }
            } else if let document = viewModel.sourceDocument {
                PageEditorView(
                    viewModel: viewModel,
                    pageRoute: activePageBinding(document: document),
                    document: document,
                    isUnifiedDocumentSurface: true,
                    onCloseDocument: closeEditor,
                    onDocumentAction: handleDocumentAction
                )
            }
        }
        .onAppear {
            ensureActivePageRoute()
        }
        .onChange(of: viewModel.pages.map(\.id)) { _, _ in
            ensureActivePageRoute()
        }
        .sheet(isPresented: $showCompression) {
            CompressionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPageNumbers) {
            PageNumbersView(viewModel: viewModel)
        }
        .sheet(isPresented: $showWatermark) {
            WatermarkView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPagesOrganizer) {
            if let document = viewModel.sourceDocument {
                DocumentPagesOrganizerSheet(
                    viewModel: viewModel,
                    document: document,
                    onSelectPage: { pageID in
                        activePageRoute = PageEditorRoute(pageItemID: pageID)
                    },
                    onDismiss: { showPagesOrganizer = false }
                )
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
    }

    @ToolbarContentBuilder
    private var emptyDocumentToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                closeEditor()
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .accessibilityLabel("New PDF")
            .accessibilityIdentifier("newPDFButton")
        }
    }

    private func activePageBinding(document: PDFDocument) -> Binding<PageEditorRoute> {
        Binding(
            get: {
                if let activePageRoute {
                    return activePageRoute
                }
                let fallback = viewModel.pages.first.map { PageEditorRoute(pageItemID: $0.id) }
                    ?? PageEditorRoute(pageItemID: UUID())
                return fallback
            },
            set: { activePageRoute = $0 }
        )
    }

    private func ensureActivePageRoute() {
        let resolved = DocumentScrollNavigationEngine.resolvedActivePageID(
            preferredID: activePageRoute?.pageItemID,
            pages: viewModel.pages
        )
        if let resolved {
            if activePageRoute?.pageItemID != resolved {
                activePageRoute = PageEditorRoute(pageItemID: resolved)
            }
        } else {
            activePageRoute = nil
        }
    }

    private func handleDocumentAction(_ action: DocumentAction) {
        switch action {
        case .compress:
            showCompression = true
        case .pageNumbers:
            showPageNumbers = true
        case .watermark:
            showWatermark = true
        case .organizePages:
            showPagesOrganizer = true
        case .export:
            handleExportTap()
        }
    }

    private func closeEditor() {
        cleanupExportFile()
        showPaywall = false
        showShareSheet = false
        exportError = nil
        activePageRoute = nil
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
