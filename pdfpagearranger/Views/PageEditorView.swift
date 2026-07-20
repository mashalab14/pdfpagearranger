import PDFKit
import PhotosUI
import SwiftUI
import UIKit

struct PageEditorRoute: Hashable {
    let pageItemID: UUID
}

struct PageEditorView: View {
    @Bindable var viewModel: PDFEditorViewModel
    @Binding var pageRoute: PageEditorRoute

    let document: PDFDocument
    var isUnifiedDocumentSurface: Bool = false
    var onCloseDocument: (() -> Void)? = nil
    var onDocumentAction: ((DocumentAction) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var pageImage: UIImage?
    @State private var pageImages: [UUID: UIImage] = [:]
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
    @State private var signatureEditOverlayID: UUID?
    @State private var signatureSaveErrorMessage: String?
    @State private var textEditingOverlayID: UUID?
    @State private var textEditingDraft = TextOverlayDraft.default
    @State private var textEditingIsNewDraft = false
    @State private var textEditingBaseline: EditorSnapshot?
    @State private var recentTexts = RecentTextsSettings.storedEntries()
    @State private var keyboardBottomInset: CGFloat = 0
    @State private var drawingModeActive = false
    @State private var drawingSessionStrokes: [DrawingStroke] = []
    @State private var drawingCurrentPoints: [PageNormalizedPoint] = []
    @State private var editingDrawingID: UUID?
    @State private var drawingColor = DrawingSettings.storedColor()
    @State private var drawingThickness = DrawingSettings.storedThickness()
    @State private var drawingEraserActive = false
    @State private var pendingStickyNotePosition: PageNormalizedPoint?
    @State private var stickyNotePlacementActive = false
    @State private var stickyNoteDraft = ""
    @State private var editingStickyNoteID: UUID?
    @State private var showStickyNoteEditor = false
    @State private var pendingCommentSelection: PDFTextSelection?
    @State private var pendingCommentHighlightID: UUID?
    @State private var editingTextCommentID: UUID?
    @State private var commentDraft = ""
    @State private var showCommentEditor = false
    @State private var annotationErrorMessage: String?
    @State private var scrollToPageToken = UUID()
    @State private var scrollActivationSuppressed = false
    @State private var scrollActivationResumeTask: Task<Void, Never>?
    @State private var latestDocumentVisibility = DocumentPageVisibility()
    @State private var interactionBlockingScroll = false
    @State private var overlayManipulationActive = false
    @State private var floatingChromeVisible = true
    @State private var floatingChromeRevealTask: Task<Void, Never>?

    private let signatureLibraryStore: SignatureLibraryStore

    init(
        viewModel: PDFEditorViewModel,
        pageRoute: Binding<PageEditorRoute>,
        document: PDFDocument,
        signatureLibraryStore: SignatureLibraryStore,
        isUnifiedDocumentSurface: Bool = false,
        onCloseDocument: (() -> Void)? = nil,
        onDocumentAction: ((DocumentAction) -> Void)? = nil
    ) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        self._pageRoute = pageRoute
        self.document = document
        self.signatureLibraryStore = signatureLibraryStore
        self.isUnifiedDocumentSurface = isUnifiedDocumentSurface
        self.onCloseDocument = onCloseDocument
        self.onDocumentAction = onDocumentAction
    }

    init(
        viewModel: PDFEditorViewModel,
        pageRoute: Binding<PageEditorRoute>,
        document: PDFDocument,
        isUnifiedDocumentSurface: Bool = false,
        onCloseDocument: (() -> Void)? = nil,
        onDocumentAction: ((DocumentAction) -> Void)? = nil
    ) {
        self.init(
            viewModel: viewModel,
            pageRoute: pageRoute,
            document: document,
            signatureLibraryStore: Self.makeDefaultSignatureLibraryStore(),
            isUnifiedDocumentSurface: isUnifiedDocumentSurface,
            onCloseDocument: onCloseDocument,
            onDocumentAction: onDocumentAction
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

    private var textEditingActive: Bool {
        textEditingOverlayID != nil
    }

    var body: some View {
        pageWithNavigation
            .sheet(isPresented: $showAddSheet, content: addOptionsSheet)
            .sheet(isPresented: $showCommentEditor, content: commentEditorSheet)
            .sheet(isPresented: $showStickyNoteEditor, content: stickyNoteEditorSheet)
            .sheet(isPresented: $showSignatureLibrary, content: signatureLibrarySheet)
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task { await importPhotoItem(newItem) }
            }
            .onChange(of: showAddSheet, handleAddSheetChange)
            .onChange(of: pageRoute.pageItemID, handlePageRouteChange)
            .onChange(of: pageSelection, handlePageSelectionChange)
            .onChange(of: viewModel.documentSearch.currentMatchIndex) { _, _ in
                syncPageToCurrentSearchMatch(animated: true)
            }
            .onChange(of: viewModel.documentSearch.isActive) { _, isActive in
                if isActive {
                    clearPDFTextSelection()
                    pageSelection = .none
                    signatureEditOverlayID = nil
                    endTextEditingIfNeeded()
                }
            }
            .onChange(of: viewModel.historyRevision) { _, _ in
                handleHistoryRestoration()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                updateKeyboardInset(from: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardBottomInset = 0
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if textEditingActive {
                    TextOverlayFormatBar(
                        draft: $textEditingDraft,
                        recentTexts: recentTexts,
                        onChange: syncLiveTextEditing,
                        onInsertRecent: { entry in
                            textEditingDraft.text = entry
                            textEditingDraft.listMode = .plain
                            textEditingDraft.listIndent = 0
                            textEditingDraft.synchronizeSpansWithTextIfNeeded()
                            syncLiveTextEditing()
                        },
                        onRemoveRecent: { entry in
                            RecentTextsSettings.removeEntry(entry)
                            recentTexts = RecentTextsSettings.storedEntries()
                        },
                        onDuplicate: {
                            guard let pageItem, let overlayID = textEditingOverlayID else { return }
                            syncLiveTextEditing()
                            duplicateTextOverlay(id: overlayID, pageItemID: pageItem.id)
                        },
                        onResetFormatting: {
                            textEditingDraft.resetFormattingPreservingText()
                            syncLiveTextEditing()
                        },
                        onDone: endTextEditingIfNeeded
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: renderTaskKey) { await loadPageImage() }
            .alert("Could Not Save Signature", isPresented: signatureSaveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(signatureSaveErrorMessage ?? "")
            }
            .alert("Annotation Error", isPresented: annotationErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(annotationErrorMessage ?? "")
            }
    }

    private var pageWithNavigation: some View {
        pageModeStack
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isUnifiedDocumentSurface ? viewModel.documentName : "Page \(pageNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isUnifiedDocumentSurface)
            .toolbar { pageToolbarContent }
    }

    private var pageModeStack: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                pageModeGuidanceBar
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !textEditingActive {
                pageBottomToolbar
                    .opacity(floatingChromeVisible ? 1 : 0)
                    .offset(y: floatingChromeVisible ? 0 : 12)
                    .allowsHitTesting(floatingChromeVisible && !drawingModeActive)
                    .animation(.easeInOut(duration: 0.2), value: floatingChromeVisible)
            }

            // Dedicated leaf so XCUITest can read active page without relying on container AX identity.
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("pageModeView")
                .accessibilityLabel("Page editor")
                .accessibilityValue("page \(pageNumber) of \(viewModel.pageCount)")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder
    private var pageModeGuidanceBar: some View {
        if viewModel.documentSearch.isActive {
            PageModeSearchBar(viewModel: viewModel) {
                viewModel.closeDocumentSearch()
            }
        } else if stickyNotePlacementActive {
            Text("Tap the page to place sticky note")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.bar)
                .accessibilityIdentifier("stickyNotePlacementGuidance")
        } else if drawingModeActive {
            DrawingModeToolbar(
                selectedColor: $drawingColor,
                selectedThickness: $drawingThickness,
                eraserActive: $drawingEraserActive,
                canUndoStroke: !drawingSessionStrokes.isEmpty,
                canClear: !drawingSessionStrokes.isEmpty || !drawingCurrentPoints.isEmpty,
                onUndoStroke: undoDrawingStroke,
                onClear: clearDrawingSession,
                onDone: finishDrawingMode
            )
        }
    }

    @ToolbarContentBuilder
    private var pageToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if isUnifiedDocumentSurface {
                Button {
                    onCloseDocument?()
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .accessibilityLabel("New PDF")
                .accessibilityIdentifier("newPDFButton")
            }

            Button {
                togglePageModeSearch()
            } label: {
                Image(systemName: viewModel.documentSearch.isActive ? "magnifyingglass.circle.fill" : "magnifyingglass")
            }
            .accessibilityLabel("Search")
            .accessibilityIdentifier(isUnifiedDocumentSurface ? "documentModeSearchButton" : "pageModeSearchButton")

            Button {
                withAnimation { viewModel.undo() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .accessibilityLabel("Undo")
            .accessibilityIdentifier(isUnifiedDocumentSurface ? "undoButton" : "pageModeUndoButton")

            Button {
                withAnimation { viewModel.redo() }
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .accessibilityLabel("Redo")
            .accessibilityIdentifier(isUnifiedDocumentSurface ? "redoButton" : "pageModeRedoButton")
        }

        if isUnifiedDocumentSurface {
            ToolbarItem(placement: .topBarTrailing) {
                DocumentActionsMenu(isEnabled: !viewModel.pages.isEmpty) { action in
                    onDocumentAction?(action)
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }

        if pageSelection.selectedOverlayID != nil || pageSelection.selectedAnnotationID != nil,
           !signaturePlacementActive,
           !drawingModeActive {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", role: .destructive) {
                    deleteSelectedItem()
                }
            }
        }
    }

    private var signatureSaveErrorBinding: Binding<Bool> {
        Binding(get: { signatureSaveErrorMessage != nil }, set: { if !$0 { signatureSaveErrorMessage = nil } })
    }

    private var annotationErrorBinding: Binding<Bool> {
        Binding(get: { annotationErrorMessage != nil }, set: { if !$0 { annotationErrorMessage = nil } })
    }

    @ViewBuilder
    private func addOptionsSheet() -> some View {
        PageAddOptionsSheet(
            onTextTapped: {
                clearPDFTextSelection()
                beginNewTextOverlay()
            },
            onImageTapped: {
                clearPDFTextSelection()
                showPhotosPicker = true
            },
            onDrawTapped: {
                clearPDFTextSelection()
                beginDrawingMode()
            },
            onStickyNoteTapped: {
                clearPDFTextSelection()
                beginStickyNotePlacement()
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

    @ViewBuilder
    private func commentEditorSheet() -> some View {
        TextCommentEditorSheet(
            title: editingTextCommentID == nil ? "Add Comment" : "Edit Comment",
            confirmTitle: editingTextCommentID == nil ? "Add" : "Save",
            selectedText: pendingCommentSelection?.text ?? commentContextSelectedText,
            commentText: $commentDraft,
            onConfirm: handleCommentEditorConfirm
        )
    }

    @ViewBuilder
    private func stickyNoteEditorSheet() -> some View {
        StickyNoteEditorSheet(
            title: editingStickyNoteID == nil ? "Add Sticky Note" : "Edit Sticky Note",
            confirmTitle: editingStickyNoteID == nil ? "Add" : "Save",
            noteText: $stickyNoteDraft,
            onConfirm: handleStickyNoteEditorConfirm
        )
    }

    @ViewBuilder
    private func signatureLibrarySheet() -> some View {
        SignatureLibraryView(
            store: signatureLibraryStore,
            showDefaultGuidanceBanner: signatureLibraryShowsDefaultGuidance
        ) { context in
            beginSignaturePlacement(context: context)
        }
    }

    private func handleAddSheetChange(_: Bool, isPresented: Bool) {
        if isPresented {
            cancelSignaturePlacement()
            endTextEditingIfNeeded()
            cancelStickyNotePlacement()
            exitDrawingMode(save: false)
            clearPDFTextSelection()
            pageSelection = .none
            signatureEditOverlayID = nil
        }
    }

    private func handlePageRouteChange(_: UUID, _: UUID) {
        cancelSignaturePlacement()
        endTextEditingIfNeeded()
        cancelStickyNotePlacement()
        exitDrawingMode(save: false)
        signatureEditOverlayID = nil
        editingStickyNoteID = nil
        editingTextCommentID = nil
        editingDrawingID = nil
        showStickyNoteEditor = false
        showCommentEditor = false
        pageSelection = .none
        bumpPDFSelectionClearToken()
        placementAnimatingOverlayIDs.removeAll()
    }

    private func handlePageSelectionChange(_ oldValue: PageModeSelection, _ newValue: PageModeSelection) {
        if case .pdfText = oldValue, newValue.pdfTextSelection == nil {
            bumpPDFSelectionClearToken()
        }
    }

    private var commentContextSelectedText: String {
        if let pendingCommentSelection {
            return pendingCommentSelection.text
        }
        if let editingTextCommentID, let pageItem,
           let comment = viewModel.annotation(id: editingTextCommentID, pageItemID: pageItem.id) {
            return comment.selectedText ?? ""
        }
        return ""
    }

    private var drawingPreviewStroke: DrawingStroke? {
        guard drawingCurrentPoints.count >= 2 else { return nil }
        return DrawingStroke(
            normalizedPoints: drawingCurrentPoints,
            colorRGBA: drawingColor.rgba,
            normalizedLineWidth: Double(drawingThickness.normalizedWidth)
        )
    }

    private var drawingCommittedStrokes: [DrawingStroke] {
        if let editingDrawingID, let pageItem,
           let annotation = viewModel.annotation(id: editingDrawingID, pageItemID: pageItem.id) {
            return annotation.strokes ?? []
        }
        return []
    }

    @ViewBuilder
    private var pageContent: some View {
        if isUnifiedDocumentSurface {
            unifiedDocumentScroll
        } else if let pageImage, let pageItem, let pdfPage = document.page(at: pageItem.originalPageIndex) {
            pageCanvas(pageItem: pageItem, pdfPage: pdfPage, pageImage: pageImage)
        } else {
            ProgressView("Loading page…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var unifiedDocumentScroll: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DocumentScrollNavigationEngine.pageSpacing(forContainerWidth: outer.size.width)) {
                        ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, item in
                            documentPageSlot(item: item, index: index, containerWidth: outer.size.width)
                                .id(item.id)
                                .background {
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: DocumentPageVisibilityKey.self,
                                            value: DocumentPageVisibility(
                                                centersInViewport: [
                                                    item.id: geo.frame(in: .named("documentScroll")).midY
                                                ],
                                                viewportHeight: outer.size.height
                                            )
                                        )
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, PageModeLayoutSizing.horizontalMargin)
                    .padding(.vertical, 8)
                }
                .coordinateSpace(name: "documentScroll")
                .scrollDisabled(interactionBlockingScroll || textEditingActive || drawingModeActive || stickyNotePlacementActive || signaturePlacementActive)
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("unifiedDocumentScroll")
                .onScrollPhaseChange { _, newPhase in
                    handleDocumentScrollPhase(newPhase)
                }
                .onPreferenceChange(DocumentPageVisibilityKey.self) { visibility in
                    latestDocumentVisibility = visibility
                    applyDocumentVisibility(visibility)
                }
                .onChange(of: pageRoute.pageItemID) { _, newID in
                    beginScrollActivationSuppression()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
                .onChange(of: scrollToPageToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(pageRoute.pageItemID, anchor: .center)
                    }
                }
                .onAppear {
                    beginScrollActivationSuppression()
                    proxy.scrollTo(pageRoute.pageItemID, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func documentPageSlot(item: PageItem, index: Int, containerWidth: CGFloat) -> some View {
        let isActive = item.id == pageRoute.pageItemID
        let image = pageImages[item.id] ?? (isActive ? pageImage : nil)
        Group {
            if let image, let pdfPage = document.page(at: item.originalPageIndex) {
                let displayWidth = max(0, containerWidth - PageModeLayoutSizing.horizontalMargin * 2)
                let displaySize = PageModeLayoutSizing.displaySize(imageSize: image.size, availableWidth: displayWidth)
                ZStack {
                    if isActive {
                        pageCanvas(pageItem: item, pdfPage: pdfPage, pageImage: image)
                            .frame(width: displaySize.width, height: displaySize.height)
                            .overlay {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(
                                        emphasizesActivePageChrome
                                            ? Color.accentColor.opacity(0.7)
                                            : Color.primary.opacity(0.06),
                                        lineWidth: emphasizesActivePageChrome ? 1.5 : 0.5
                                    )
                            }
                            .shadow(
                                color: .black.opacity(emphasizesActivePageChrome ? 0.12 : 0.06),
                                radius: emphasizesActivePageChrome ? 6 : 3,
                                y: emphasizesActivePageChrome ? 3 : 1
                            )
                    } else {
                        DocumentInactivePagePreview(
                            pageImage: image,
                            objects: viewModel.overlayObjects(for: item.id),
                            overlayImages: viewModel.overlayImages(for: item.id),
                            pageRotation: item.rotation,
                            isActiveChrome: false
                        )
                        .frame(width: displaySize.width, height: displaySize.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activatePage(id: item.id, scroll: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("documentPageSlot_\(index + 1)")
                .accessibilityValue(isActive ? "active" : "inactive")
                .accessibilityLabel(isActive ? "Active page \(index + 1)" : "Page \(index + 1)")
                .task(id: pageRenderKey(for: item, index: index)) {
                    await loadPageImage(for: item, exportIndex: index)
                }
            } else {
                ProgressView("Loading page…")
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .task(id: pageRenderKey(for: item, index: index)) {
                        await loadPageImage(for: item, exportIndex: index)
                    }
            }
        }
    }

    private func pageRenderKey(for item: PageItem, index: Int) -> String {
        "\(item.id.uuidString)-\(item.rotation)-\(viewModel.pageNumberSettings.thumbnailCacheKeySuffix)-\(viewModel.watermarkSettings.thumbnailCacheKeySuffix)-\(index)-\(viewModel.pageCount)-\(viewModel.historyRevision)-\(viewModel.overlayRevision(for: item.id))"
    }

    private func activatePage(id: UUID, scroll: Bool) {
        guard id != pageRoute.pageItemID else {
            if scroll {
                beginScrollActivationSuppression()
                scrollToPageToken = UUID()
            }
            return
        }
        endTextEditingIfNeeded()
        cancelSignaturePlacement()
        cancelStickyNotePlacement()
        if drawingModeActive {
            exitDrawingMode(save: false)
        }
        pageSelection = .none
        signatureEditOverlayID = nil
        clearPDFTextSelection()
        if scroll {
            beginScrollActivationSuppression()
        }
        pageRoute = PageEditorRoute(pageItemID: id)
        if scroll {
            scrollToPageToken = UUID()
        }
    }

    private func beginScrollActivationSuppression(durationNanoseconds: UInt64 = 750_000_000) {
        scrollActivationSuppressed = true
        scrollActivationResumeTask?.cancel()
        scrollActivationResumeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            guard !Task.isCancelled else { return }
            scrollActivationSuppressed = false
            // Apply any scroll movement that happened while programmatic activation was settling.
            applyDocumentVisibility(latestDocumentVisibility)
        }
    }

    private func applyDocumentVisibility(_ visibility: DocumentPageVisibility) {
        guard isUnifiedDocumentSurface else { return }
        let proposed = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: visibility.centersInViewport,
            viewportHeight: visibility.viewportHeight,
            fallback: pageRoute.pageItemID
        )
        if DocumentScrollNavigationEngine.shouldUpdateActivePage(
            proposedID: proposed,
            currentID: pageRoute.pageItemID,
            interactionBlockingScroll: interactionBlockingScroll
                || textEditingActive
                || drawingModeActive
                || scrollActivationSuppressed
        ), let proposed {
            activatePage(id: proposed, scroll: false)
        }
    }

    private func pageCanvas(pageItem: PageItem, pdfPage: PDFPage, pageImage: UIImage) -> PageOverlayCanvasView {
        PageOverlayCanvasView(
            pageImage: pageImage,
            pdfPage: pdfPage,
            pageRotation: pageItem.rotation,
            pageLoadKey: "\(pageItem.id.uuidString)-\(pageItem.rotation)",
            objects: viewModel.overlayObjects(for: pageItem.id),
            annotations: viewModel.annotations(for: pageItem.id),
            searchMatchesOnPage: viewModel.documentSearch.isActive
                ? viewModel.documentSearch.results.matches(on: pageItem.id)
                : [],
            activeSearchMatchID: viewModel.documentSearch.currentMatch?.pageItemID == pageItem.id
                ? viewModel.documentSearch.currentMatch?.id
                : nil,
            placementAnimatingOverlayIDs: placementAnimatingOverlayIDs,
            onPlacementAnimationFinished: { overlayID in
                placementAnimatingOverlayIDs.remove(overlayID)
            },
            signaturePlacementActive: signaturePlacementActive,
            onSignaturePlacementTap: { location, displaySize in
                placeSignature(atDisplayTap: location, displayPageSize: displaySize)
            },
            onSignaturePlacementDismiss: cancelSignaturePlacement,
            textEditingOverlayID: textEditingOverlayID,
            textEditingDraft: $textEditingDraft,
            onTextEditingChanged: syncLiveTextEditing,
            onEndTextEditing: endTextEditingIfNeeded,
            stickyNotePlacementActive: stickyNotePlacementActive,
            onStickyNotePlacementTap: { location, displaySize in
                placeStickyNote(atDisplayTap: location, displayPageSize: displaySize)
            },
            onStickyNotePlacementDismiss: cancelStickyNotePlacement,
            drawingModeActive: drawingModeActive,
            drawingCommittedStrokes: drawingCommittedStrokes,
            drawingSessionStrokes: drawingSessionStrokes,
            drawingPreviewStroke: drawingPreviewStroke,
            drawingEraserActive: drawingEraserActive,
            onDrawingStrokeBegan: beginDrawingStroke,
            onDrawingStrokeChanged: continueDrawingStroke,
            onDrawingStrokeEnded: finishDrawingStroke,
            onDrawingEraseAt: eraseDrawingStroke,
            pageSelection: $pageSelection,
            pdfSelectionClearToken: pdfSelectionClearToken,
            imageProvider: { viewModel.imageAsset(for: $0) },
            onUpdate: { viewModel.updateOverlay($0) },
            onDelete: { viewModel.deleteOverlay(id: $0, pageItemID: pageItem.id) },
            onPageSwipe: isUnifiedDocumentSurface || drawingModeActive || stickyNotePlacementActive
                ? nil
                : { direction in
                    navigateToAdjacentPage(direction: direction)
                },
            onPDFTextMenuCopy: copySelectedPDFText,
            onPDFTextHighlight: createHighlight,
            onPDFTextComment: beginTextComment,
            onSelectAnnotation: { _ in },
            onDeleteAnnotation: { id in
                viewModel.deleteAnnotation(id: id, pageItemID: pageItem.id)
            },
            onHighlightColorChange: { id, color in
                _ = viewModel.updateHighlightColor(id: id, pageItemID: pageItem.id, color: color)
            },
            onHighlightComment: beginCommentForHighlight,
            onEditStickyNote: beginEditingStickyNote,
            onEditTextComment: beginEditingTextComment,
            onMoveStickyNote: { id, position in
                _ = viewModel.moveStickyNote(id: id, pageItemID: pageItem.id, normalizedPosition: position)
            },
            signatureEditOverlayID: $signatureEditOverlayID,
            pageItemID: pageItem.id,
            onUpdateSignatureAppearance: { overlayID, color, widthPoints in
                viewModel.updatePlacedSignatureAppearance(
                    overlayID: overlayID,
                    pageItemID: pageItem.id,
                    inkColor: color,
                    strokeWidthPoints: widthPoints
                )
            },
            onUpdateSignatureCustomColor: { overlayID, uiColor, widthPoints in
                viewModel.updatePlacedSignatureCustomColor(
                    overlayID: overlayID,
                    pageItemID: pageItem.id,
                    color: uiColor,
                    strokeWidthPoints: widthPoints
                )
            },
            onResetSignatureAppearance: { overlayID in
                viewModel.resetPlacedSignatureAppearance(
                    overlayID: overlayID,
                    pageItemID: pageItem.id
                )
            },
            onSaveSignatureToLibrary: { overlayID in
                savePlacedSignatureToLibrary(overlayID: overlayID, pageItemID: pageItem.id)
            },
            onEditTextOverlay: { overlayID in
                beginEditingTextOverlay(id: overlayID, pageItemID: pageItem.id)
            },
            onDuplicateTextOverlay: { overlayID in
                duplicateTextOverlay(id: overlayID, pageItemID: pageItem.id)
            },
            onDeleteTextOverlay: { overlayID in
                viewModel.deleteOverlay(id: overlayID, pageItemID: pageItem.id)
                if pageSelection.selectedOverlayID == overlayID {
                    pageSelection = .none
                }
            },
            pageTransitionEdge: pageTransitionEdge,
            keyboardBottomInset: keyboardBottomInset,
            onCanvasScrollBlockingChange: { blocking in
                interactionBlockingScroll = blocking
            },
            onOverlayManipulationActiveChange: { active in
                overlayManipulationActive = active
            }
        )
    }

    private var emphasizesActivePageChrome: Bool {
        pageSelection != .none
            || textEditingActive
            || signaturePlacementActive
            || stickyNotePlacementActive
            || drawingModeActive
            || signatureEditOverlayID != nil
            || overlayManipulationActive
    }

    private var pageBottomToolbar: some View {
        HStack(alignment: .bottom, spacing: 14) {
            if isUnifiedDocumentSurface {
                floatingPageActionsCapsule
            }

            Spacer(minLength: 0)

            floatingAddButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .safeAreaPadding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pageBottomToolbar")
    }

    private var floatingPageActionsCapsule: some View {
        HStack(spacing: 4) {
            Button {
                guard let pageItem else { return }
                viewModel.rotatePage(id: pageItem.id)
            } label: {
                Image(systemName: "rotate.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Rotate Page")
            .accessibilityIdentifier("pageToolbarRotate")

            Button {
                guard let pageItem else { return }
                let index = viewModel.pageIndex(for: pageItem.id) ?? 0
                viewModel.duplicatePage(id: pageItem.id)
                if viewModel.pages.indices.contains(index + 1) {
                    activatePage(id: viewModel.pages[index + 1].id, scroll: true)
                }
            } label: {
                Image(systemName: "plus.square.on.square")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Duplicate Page")
            .accessibilityIdentifier("pageToolbarDuplicate")

            Button(role: .destructive) {
                guard let pageItem else { return }
                let index = viewModel.pageIndex(for: pageItem.id) ?? 0
                viewModel.deletePage(id: pageItem.id)
                if viewModel.pages.isEmpty { return }
                let nextIndex = min(index, viewModel.pages.count - 1)
                activatePage(id: viewModel.pages[nextIndex].id, scroll: true)
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Delete Page")
            .accessibilityIdentifier("pageToolbarDelete")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("floatingPageToolbar")
    }

    private var floatingAddButton: some View {
        Button {
            clearPDFTextSelection()
            pageSelection = .none
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(drawingModeActive)
        .opacity(drawingModeActive ? 0.45 : 1)
        .accessibilityLabel("Add")
        .accessibilityIdentifier("pageModeAddButton")
    }

    private var addButtonBar: some View {
        pageBottomToolbar
    }

    private func handleDocumentScrollPhase(_ phase: ScrollPhase) {
        switch phase {
        case .idle:
            scheduleFloatingChromeReveal()
        default:
            floatingChromeRevealTask?.cancel()
            guard floatingChromeVisible else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                floatingChromeVisible = false
            }
        }
    }

    private func scheduleFloatingChromeReveal() {
        floatingChromeRevealTask?.cancel()
        floatingChromeRevealTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: DocumentScrollNavigationEngine.floatingChromeRevealDelayNanoseconds
            )
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                floatingChromeVisible = true
            }
        }
    }

    private var renderTaskKey: String {
        guard let pageItem else { return "missing-page" }
        let exportIndex = viewModel.pageIndex(for: pageItem.id) ?? (pageNumber - 1)
        return "\(pageItem.id.uuidString)-\(pageItem.rotation)-\(viewModel.pageNumberSettings.thumbnailCacheKeySuffix)-\(viewModel.watermarkSettings.thumbnailCacheKeySuffix)-\(exportIndex)-\(viewModel.pageCount)-\(viewModel.historyRevision)-\(viewModel.overlayRevision(for: pageItem.id))"
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
        await loadPageImage(for: pageItem, exportIndex: exportIndex)
    }

    private func loadPageImage(for pageItem: PageItem, exportIndex: Int) async {
        let pageID = pageItem.id
        let image = await PageRenderService.shared.pageImage(
            for: pageItem,
            document: document,
            pageNumberSettings: viewModel.pageNumberSettings,
            watermarkSettings: viewModel.watermarkSettings,
            watermarkImage: viewModel.watermarkImage,
            exportIndex: exportIndex,
            totalPages: viewModel.pageCount
        )
        guard let image else { return }
        pageImages[pageID] = image
        if self.pageItem?.id == pageID {
            pageImage = image
        }
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

    private func deleteSelectedItem() {
        guard let pageItem else { return }
        if let overlayID = pageSelection.selectedOverlayID {
            signatureEditOverlayID = nil
            viewModel.deleteOverlay(id: overlayID, pageItemID: pageItem.id)
            pageSelection = .none
            return
        }
        if let annotationID = pageSelection.selectedAnnotationID {
            viewModel.deleteAnnotation(id: annotationID, pageItemID: pageItem.id)
            pageSelection = .none
        }
    }

    private func deleteSelectedOverlay() {
        deleteSelectedItem()
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
        signatureEditOverlayID = nil
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

    private func handleHistoryRestoration() {
        clearTransientInteractionStateForHistoryRestore()

        if viewModel.pages.isEmpty {
            if isUnifiedDocumentSurface {
                onCloseDocument?()
            } else {
                dismiss()
            }
            return
        }

        let preferredIndex = max(0, pageNumber - 1)
        guard let resolvedID = viewModel.resolvedPageItemID(
            currentID: pageRoute.pageItemID,
            preferredIndex: preferredIndex
        ) else {
            if isUnifiedDocumentSurface {
                onCloseDocument?()
            } else {
                dismiss()
            }
            return
        }

        if resolvedID != pageRoute.pageItemID {
            pageRoute = PageEditorRoute(pageItemID: resolvedID)
        }

        validateSelectionAfterHistoryRestore()
    }

    private func clearTransientInteractionStateForHistoryRestore() {
        clearPDFTextSelection()
        pendingSignaturePlacement = nil
        discardTextEditingSession(commit: false)
        signatureEditOverlayID = nil
        drawingModeActive = false
        drawingSessionStrokes = []
        drawingCurrentPoints = []
        editingDrawingID = nil
        drawingEraserActive = false
        pendingStickyNotePosition = nil
        stickyNotePlacementActive = false
        editingStickyNoteID = nil
        showStickyNoteEditor = false
        pendingCommentSelection = nil
        pendingCommentHighlightID = nil
        editingTextCommentID = nil
        showCommentEditor = false
        showAddSheet = false
    }

    private func validateSelectionAfterHistoryRestore() {
        guard let pageItem else {
            pageSelection = .none
            signatureEditOverlayID = nil
            return
        }

        switch pageSelection {
        case .none:
            break
        case .overlay(let id):
            if !viewModel.overlayExists(id: id, pageItemID: pageItem.id) {
                pageSelection = .none
                signatureEditOverlayID = nil
            }
        case .pdfText:
            pageSelection = .none
        case .highlight(let id), .drawing(let id), .stickyNote(let id), .textComment(let id):
            if !viewModel.annotationExists(id: id, pageItemID: pageItem.id) {
                pageSelection = .none
            }
        }
    }

    private func bumpPDFSelectionClearToken() {
        pdfSelectionClearToken = UUID()
    }

    private func togglePageModeSearch() {
        if viewModel.documentSearch.isActive {
            viewModel.closeDocumentSearch()
            return
        }

        cancelSignaturePlacement()
        endTextEditingIfNeeded()
        cancelStickyNotePlacement()
        exitDrawingMode(save: false)
        clearPDFTextSelection()
        pageSelection = .none
        signatureEditOverlayID = nil
        viewModel.openDocumentSearch()
    }

    private func syncPageToCurrentSearchMatch(animated: Bool) {
        guard viewModel.documentSearch.isActive,
              let match = viewModel.documentSearch.currentMatch,
              match.pageItemID != pageRoute.pageItemID else {
            return
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                activatePage(id: match.pageItemID, scroll: true)
            }
        } else {
            activatePage(id: match.pageItemID, scroll: true)
        }
    }

    private func registerNewOverlayPlacement(overlayID: UUID) {
        placementAnimatingOverlayIDs.insert(overlayID)
        OverlayPlacementFeedback.playPlacementHaptic()
        pageSelection = .overlay(overlayID)
    }

    private func navigateToAdjacentPage(direction: PageModeNavigationDirection) {
        guard !isUnifiedDocumentSurface else { return }
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

    private func savePlacedSignatureToLibrary(overlayID: UUID, pageItemID: UUID) {
        do {
            _ = try viewModel.savePlacedSignatureToLibrary(
                overlayID: overlayID,
                pageItemID: pageItemID,
                store: signatureLibraryStore
            )
        } catch {
            signatureSaveErrorMessage = error.localizedDescription
        }
    }

    private func beginNewTextOverlay() {
        guard let pageItem else { return }
        cancelSignaturePlacement()
        cancelStickyNotePlacement()
        exitDrawingMode(save: false)
        endTextEditingIfNeeded()

        let baseline = viewModel.captureEditorSnapshot()
        let draft = TextOverlayDraft.default
        let overlayID = viewModel.beginDraftTextOverlay(
            to: pageItem.id,
            draft: draft,
            pageAspectRatio: pageAspectRatio,
            at: CGPoint(x: 0.5, y: 0.42)
        )

        textEditingBaseline = baseline
        textEditingIsNewDraft = true
        textEditingDraft = draft
        textEditingOverlayID = overlayID
        recentTexts = RecentTextsSettings.storedEntries()
        registerNewOverlayPlacement(overlayID: overlayID)
        pageSelection = .overlay(overlayID)
    }

    private func beginEditingTextOverlay(id: UUID, pageItemID: UUID) {
        guard let overlay = viewModel.overlayObjects(for: pageItemID).first(where: { $0.id == id && $0.type == .text }) else {
            return
        }
        cancelSignaturePlacement()
        if textEditingOverlayID != id {
            endTextEditingIfNeeded()
        }

        textEditingBaseline = viewModel.captureEditorSnapshot()
        textEditingIsNewDraft = false
        textEditingDraft = TextOverlayDraft(from: overlay)
        textEditingOverlayID = id
        recentTexts = RecentTextsSettings.storedEntries()
        pageSelection = .overlay(id)
    }

    private func syncLiveTextEditing() {
        guard let pageItem, let overlayID = textEditingOverlayID else { return }
        textEditingDraft.clampListIndent()
        _ = viewModel.syncTextOverlayDraft(
            id: overlayID,
            pageItemID: pageItem.id,
            draft: textEditingDraft,
            pageAspectRatio: pageAspectRatio,
            preserveWidth: true
        )
    }

    private func endTextEditingIfNeeded() {
        guard textEditingActive else { return }
        commitTextEditing()
    }

    private func commitTextEditing() {
        guard let pageItem, let overlayID = textEditingOverlayID else {
            discardTextEditingSession(commit: false)
            return
        }

        let result = viewModel.commitTextOverlayEditing(
            id: overlayID,
            pageItemID: pageItem.id,
            draft: textEditingDraft,
            pageAspectRatio: pageAspectRatio,
            isNewDraft: textEditingIsNewDraft,
            baselineSnapshot: textEditingBaseline
        )

        switch result {
        case .cancelledEmptyDraft:
            if pageSelection.selectedOverlayID == overlayID {
                pageSelection = .none
            }
        case .deletedEmptyExisting:
            if pageSelection.selectedOverlayID == overlayID {
                pageSelection = .none
            }
        case .committed:
            pageSelection = .overlay(overlayID)
            recentTexts = RecentTextsSettings.storedEntries()
        case .rejected:
            break
        }

        discardTextEditingSession(commit: false)
    }

    private func discardTextEditingSession(commit: Bool) {
        _ = commit
        textEditingOverlayID = nil
        textEditingDraft = .default
        textEditingIsNewDraft = false
        textEditingBaseline = nil
    }

    private func updateKeyboardInset(from notification: Notification) {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            keyboardBottomInset = 0
            return
        }
        let screenHeight = UIScreen.main.bounds.height
        keyboardBottomInset = max(0, screenHeight - frame.origin.y)
    }

    private func duplicateTextOverlay(id: UUID, pageItemID: UUID) {
        guard let duplicateID = viewModel.duplicateOverlay(id: id, pageItemID: pageItemID) else { return }
        registerNewOverlayPlacement(overlayID: duplicateID)
    }

    private func createHighlight(from selection: PDFTextSelection) {
        guard let pageItem else { return }
        guard !selection.normalizedRects.isEmpty else {
            annotationErrorMessage = "Could not create a highlight for this selection."
            return
        }
        guard let highlightID = viewModel.addHighlight(
            to: pageItem.id,
            normalizedRects: selection.normalizedRects,
            selectedText: selection.text
        ) else {
            annotationErrorMessage = "Could not create a highlight for this selection."
            return
        }
        clearPDFTextSelection()
        OverlayPlacementFeedback.playPlacementHaptic()
        pageSelection = .highlight(highlightID)
    }

    private func beginTextComment(from selection: PDFTextSelection) {
        pendingCommentSelection = selection
        pendingCommentHighlightID = nil
        editingTextCommentID = nil
        commentDraft = ""
        showCommentEditor = true
    }

    private func beginCommentForHighlight(_ highlightID: UUID) {
        guard let pageItem,
              let highlight = viewModel.annotation(id: highlightID, pageItemID: pageItem.id) else {
            return
        }
        pendingCommentSelection = PDFTextSelection(
            text: highlight.selectedText ?? "",
            anchorRect: .zero,
            normalizedRects: highlight.normalizedRects ?? []
        )
        pendingCommentHighlightID = highlightID
        editingTextCommentID = nil
        commentDraft = ""
        showCommentEditor = true
    }

    private func beginEditingTextComment(_ commentID: UUID) {
        guard let pageItem,
              let comment = viewModel.annotation(id: commentID, pageItemID: pageItem.id) else {
            return
        }
        editingTextCommentID = commentID
        pendingCommentSelection = nil
        pendingCommentHighlightID = comment.linkedHighlightID
        commentDraft = comment.commentText ?? ""
        showCommentEditor = true
    }

    private func handleCommentEditorConfirm() {
        guard let pageItem else { return }
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            annotationErrorMessage = "Enter comment text before continuing."
            return
        }

        if let editingTextCommentID {
            guard viewModel.updateTextComment(id: editingTextCommentID, pageItemID: pageItem.id, commentText: trimmed) else {
                annotationErrorMessage = "Enter comment text before continuing."
                return
            }
            self.editingTextCommentID = nil
            showCommentEditor = false
            pageSelection = .textComment(editingTextCommentID)
            return
        }

        guard let selection = pendingCommentSelection, !selection.normalizedRects.isEmpty else {
            annotationErrorMessage = "Could not save this comment."
            return
        }

        guard let commentID = viewModel.addTextComment(
            to: pageItem.id,
            normalizedRects: selection.normalizedRects,
            selectedText: selection.text,
            commentText: trimmed,
            linkedHighlightID: pendingCommentHighlightID
        ) else {
            annotationErrorMessage = "Enter comment text before continuing."
            return
        }

        pendingCommentSelection = nil
        pendingCommentHighlightID = nil
        showCommentEditor = false
        clearPDFTextSelection()
        OverlayPlacementFeedback.playPlacementHaptic()
        pageSelection = .textComment(commentID)
    }

    private func beginStickyNotePlacement() {
        cancelSignaturePlacement()
        endTextEditingIfNeeded()
        exitDrawingMode(save: false)
        stickyNotePlacementActive = true
        pendingStickyNotePosition = nil
        pageSelection = .none
    }

    private func cancelStickyNotePlacement() {
        stickyNotePlacementActive = false
        pendingStickyNotePosition = nil
    }

    private func placeStickyNote(atDisplayTap tap: CGPoint, displayPageSize: CGSize) {
        guard let pageItem else { return }
        guard let storagePoint = AnnotationGeometryEngine.displayTapToStoragePoint(
            tap: tap,
            displayPageSize: displayPageSize,
            pageRotation: pageItem.rotation
        ) else {
            cancelStickyNotePlacement()
            return
        }
        stickyNotePlacementActive = false
        pendingStickyNotePosition = storagePoint
        editingStickyNoteID = nil
        stickyNoteDraft = ""
        showStickyNoteEditor = true
    }

    private func beginEditingStickyNote(_ noteID: UUID) {
        guard let pageItem,
              let note = viewModel.annotation(id: noteID, pageItemID: pageItem.id) else {
            return
        }
        editingStickyNoteID = noteID
        stickyNoteDraft = note.noteText ?? ""
        showStickyNoteEditor = true
    }

    private func handleStickyNoteEditorConfirm() {
        guard let pageItem else { return }
        let trimmed = stickyNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            annotationErrorMessage = "Enter note text before continuing."
            return
        }

        if let editingStickyNoteID {
            guard viewModel.updateStickyNote(id: editingStickyNoteID, pageItemID: pageItem.id, noteText: trimmed) else {
                annotationErrorMessage = "Enter note text before continuing."
                return
            }
            self.editingStickyNoteID = nil
            showStickyNoteEditor = false
            pageSelection = .stickyNote(editingStickyNoteID)
            return
        }

        guard let position = pendingStickyNotePosition else {
            annotationErrorMessage = "Could not save this sticky note."
            return
        }

        guard let noteID = viewModel.addStickyNote(
            to: pageItem.id,
            normalizedPosition: position,
            noteText: trimmed
        ) else {
            annotationErrorMessage = "Enter note text before continuing."
            return
        }

        pendingStickyNotePosition = nil
        showStickyNoteEditor = false
        OverlayPlacementFeedback.playPlacementHaptic()
        pageSelection = .stickyNote(noteID)
    }

    private func beginDrawingMode() {
        cancelSignaturePlacement()
        endTextEditingIfNeeded()
        cancelStickyNotePlacement()
        clearPDFTextSelection()
        pageSelection = .none
        drawingModeActive = true
        drawingSessionStrokes = []
        drawingCurrentPoints = []
        drawingEraserActive = false
        editingDrawingID = nil
        drawingColor = DrawingSettings.storedColor()
        drawingThickness = DrawingSettings.storedThickness()
    }

    private func exitDrawingMode(save: Bool) {
        if save {
            finishDrawingMode()
            return
        }
        drawingModeActive = false
        drawingSessionStrokes = []
        drawingCurrentPoints = []
        editingDrawingID = nil
        drawingEraserActive = false
    }

    private func finishDrawingMode() {
        guard let pageItem else {
            drawingModeActive = false
            return
        }

        let allStrokes = drawingCommittedStrokes + drawingSessionStrokes
        guard !allStrokes.isEmpty else {
            drawingModeActive = false
            drawingSessionStrokes = []
            drawingCurrentPoints = []
            editingDrawingID = nil
            return
        }

        if let editingDrawingID {
            _ = viewModel.replaceDrawingAnnotation(id: editingDrawingID, pageItemID: pageItem.id, strokes: allStrokes)
            pageSelection = .drawing(editingDrawingID)
        } else if let drawingID = viewModel.addDrawingAnnotation(to: pageItem.id, strokes: allStrokes) {
            OverlayPlacementFeedback.playPlacementHaptic()
            pageSelection = .drawing(drawingID)
        }

        drawingModeActive = false
        drawingSessionStrokes = []
        drawingCurrentPoints = []
        editingDrawingID = nil
        drawingEraserActive = false
    }

    private func beginDrawingStroke(at location: CGPoint, displayPageSize: CGSize) {
        guard let pageItem else { return }
        drawingCurrentPoints = []
        DrawingStrokeBuilder.appendPoint(
            displayPoint: location,
            displayPageSize: displayPageSize,
            pageRotation: pageItem.rotation,
            to: &drawingCurrentPoints
        )
    }

    private func continueDrawingStroke(at location: CGPoint, displayPageSize: CGSize) {
        guard let pageItem else { return }
        DrawingStrokeBuilder.appendPoint(
            displayPoint: location,
            displayPageSize: displayPageSize,
            pageRotation: pageItem.rotation,
            to: &drawingCurrentPoints
        )
    }

    private func finishDrawingStroke() {
        guard let stroke = DrawingStrokeBuilder.makeStroke(
            from: drawingCurrentPoints,
            color: drawingColor,
            thickness: drawingThickness
        ) else {
            drawingCurrentPoints = []
            return
        }
        drawingSessionStrokes.append(stroke)
        drawingCurrentPoints = []
    }

    private func undoDrawingStroke() {
        if !drawingCurrentPoints.isEmpty {
            drawingCurrentPoints = []
            return
        }
        _ = drawingSessionStrokes.popLast()
    }

    private func clearDrawingSession() {
        drawingCurrentPoints = []
        drawingSessionStrokes = []
    }

    private func eraseDrawingStroke(at location: CGPoint, displayPageSize: CGSize) {
        guard let pageItem else { return }
        if let index = AnnotationHitTestEngine.strokeIndex(
            at: location,
            displayPageSize: displayPageSize,
            strokes: drawingSessionStrokes,
            pageRotation: pageItem.rotation
        ) {
            drawingSessionStrokes.remove(at: index)
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
