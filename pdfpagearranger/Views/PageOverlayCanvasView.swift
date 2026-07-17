import PDFKit
import SwiftUI
import UIKit

struct PageOverlayCanvasView: View {
    let pageImage: UIImage
    let pdfPage: PDFPage
    let pageRotation: Int
    let pageLoadKey: String
    let objects: [PageObject]
    let annotations: [PageAnnotation]
    let searchMatchesOnPage: [DocumentSearchMatch]
    let activeSearchMatchID: UUID?
    let placementAnimatingOverlayIDs: Set<UUID>
    let onPlacementAnimationFinished: (UUID) -> Void
    let signaturePlacementActive: Bool
    let onSignaturePlacementTap: ((CGPoint, CGSize) -> Void)?
    let onSignaturePlacementDismiss: (() -> Void)?
    let textEditingOverlayID: UUID?
    @Binding var textEditingDraft: TextOverlayDraft
    let onTextEditingChanged: () -> Void
    let onEndTextEditing: () -> Void
    let stickyNotePlacementActive: Bool
    let onStickyNotePlacementTap: ((CGPoint, CGSize) -> Void)?
    let onStickyNotePlacementDismiss: (() -> Void)?
    let drawingModeActive: Bool
    let drawingCommittedStrokes: [DrawingStroke]
    let drawingSessionStrokes: [DrawingStroke]
    let drawingPreviewStroke: DrawingStroke?
    let drawingEraserActive: Bool
    let onDrawingStrokeBegan: (CGPoint, CGSize) -> Void
    let onDrawingStrokeChanged: (CGPoint, CGSize) -> Void
    let onDrawingStrokeEnded: () -> Void
    let onDrawingEraseAt: (CGPoint, CGSize) -> Void
    @Binding var pageSelection: PageModeSelection
    let pdfSelectionClearToken: UUID
    let imageProvider: (UUID) -> UIImage?
    let onUpdate: (PageObject) -> Void
    let onDelete: (UUID) -> Void
    let onPageSwipe: ((PageModeNavigationDirection) -> Void)?
    let onPDFTextMenuCopy: (String) -> Void
    let onPDFTextHighlight: (PDFTextSelection) -> Void
    let onPDFTextComment: (PDFTextSelection) -> Void
    let onSelectAnnotation: (PageAnnotation) -> Void
    let onDeleteAnnotation: (UUID) -> Void
    let onHighlightColorChange: (UUID, HighlightPresetColor) -> Void
    let onHighlightComment: (UUID) -> Void
    let onEditStickyNote: (UUID) -> Void
    let onEditTextComment: (UUID) -> Void
    let onMoveStickyNote: (UUID, PageNormalizedPoint) -> Void
    @Binding var signatureEditOverlayID: UUID?
    let pageItemID: UUID
    let onUpdateSignatureAppearance: (UUID, SignatureInkColor, Int) -> Void
    let onUpdateSignatureCustomColor: (UUID, UIColor, Int) -> Void
    let onResetSignatureAppearance: (UUID) -> Void
    let onSaveSignatureToLibrary: (UUID) -> Void
    let onEditTextOverlay: (UUID) -> Void
    let onDuplicateTextOverlay: (UUID) -> Void
    let onDeleteTextOverlay: (UUID) -> Void
    let pageTransitionEdge: Edge
    var keyboardBottomInset: CGFloat = 0

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @State private var overlayManipulationState = OverlayManipulationState()
    @State private var pdfTextSelectionLayerActive = false
    @State private var stickyNoteDragOffset: CGSize = .zero
    @State private var stickyNoteDragOrigin: PageNormalizedPoint?

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    private var textEditingActive: Bool {
        textEditingOverlayID != nil
    }

    private var pageZoomEnabled: Bool {
        pageSelection.selectedOverlayID == nil
            && pageSelection.selectedAnnotationID == nil
            && !signaturePlacementActive
            && !textEditingActive
            && !stickyNotePlacementActive
            && !drawingModeActive
    }

    private var pageSwipeEnabled: Bool {
        !signaturePlacementActive
            && !textEditingActive
            && !stickyNotePlacementActive
            && !drawingModeActive
            && stickyNoteDragOrigin == nil
            && onPageSwipe != nil
            && PageModeNavigationEngine.shouldAllowPageSwipe(
                overlayManipulationActive: overlayManipulationState.isActive,
                isPageZoomed: isPageZoomed
            )
    }

    private var selectedHighlight: PageAnnotation? {
        guard case .highlight(let id) = pageSelection else { return nil }
        return annotations.first { $0.id == id && $0.kind == .highlight }
    }

    private var selectedStickyNote: PageAnnotation? {
        guard case .stickyNote(let id) = pageSelection else { return nil }
        return annotations.first { $0.id == id && $0.kind == .stickyNote }
    }

    private var selectedTextComment: PageAnnotation? {
        guard case .textComment(let id) = pageSelection else { return nil }
        return annotations.first { $0.id == id && $0.kind == .textComment }
    }

    private var selectedDrawing: PageAnnotation? {
        guard case .drawing(let id) = pageSelection else { return nil }
        return annotations.first { $0.id == id && $0.kind == .drawing }
    }

    private var isPageZoomed: Bool {
        scale > minScale + 0.01 || offset != .zero
    }

    private var annotationInteractionEnabled: Bool {
        !signaturePlacementActive
            && !textEditingActive
            && !stickyNotePlacementActive
            && !drawingModeActive
            && signatureEditOverlayID == nil
    }

    private var selectedSignatureOverlay: PageObject? {
        guard let overlayID = pageSelection.selectedOverlayID,
              let object = objects.first(where: { $0.id == overlayID }),
              object.type == .signature else {
            return nil
        }
        return object
    }

    private var selectedTextOverlay: PageObject? {
        guard let overlayID = pageSelection.selectedOverlayID,
              let object = objects.first(where: { $0.id == overlayID }),
              object.type == .text else {
            return nil
        }
        return object
    }

    private var showsTextContextMenu: Bool {
        selectedTextOverlay != nil
            && !signaturePlacementActive
            && !textEditingActive
            && !overlayManipulationState.isActive
    }

    private var showsSignatureContextMenu: Bool {
        selectedSignatureOverlay != nil
            && signatureEditOverlayID == nil
            && !signaturePlacementActive
            && !textEditingActive
            && !overlayManipulationState.isActive
    }

    private var editingSignatureOverlay: PageObject? {
        guard let overlayID = signatureEditOverlayID else { return nil }
        return objects.first(where: { $0.id == overlayID && $0.type == .signature })
    }

    var body: some View {
        GeometryReader { geometry in
            let displaySize = PageModeLayoutSizing.displaySize(
                imageSize: pageImage.size,
                containerSize: geometry.size,
                leadingSafeAreaInset: geometry.safeAreaInsets.leading,
                trailingSafeAreaInset: geometry.safeAreaInsets.trailing
            )

            ZStack(alignment: .top) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleCanvasBackgroundTap()
                    }

                pageStack(fitSize: displaySize)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .scaleEffect(scale)
                    .offset(
                        x: offset.width,
                        y: offset.height - (textEditingActive ? min(max(keyboardBottomInset - 40, 0) * 0.55, 260) : 0)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        handlePageTap(at: location, displaySize: displaySize)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .gesture(pageZoomEnabled ? magnificationGesture : nil)
            .simultaneousGesture(pageZoomEnabled ? panGesture : nil)
            .simultaneousGesture(pageSwipeEnabled ? pageSwipeGesture : nil)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pageModeCanvas")
            .onLongPressGesture(minimumDuration: 0.35) {
                guard !signaturePlacementActive,
                      !textEditingActive,
                      !stickyNotePlacementActive,
                      !drawingModeActive else { return }
                pdfTextSelectionLayerActive = true
            }
            .onChange(of: signaturePlacementActive) { _, isActive in
                if isActive {
                    deactivatePDFTextSelectionLayer()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        resetZoom()
                    }
                }
            }
            .onChange(of: textEditingActive) { _, isActive in
                if isActive {
                    deactivatePDFTextSelectionLayer()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        resetZoom()
                    }
                }
            }
            .onChange(of: pageLoadKey) { _, _ in
                deactivatePDFTextSelectionLayer()
                withAnimation(.easeInOut(duration: 0.2)) {
                    resetZoom()
                }
            }
            .onChange(of: pageSelection) { _, newValue in
                if newValue.pdfTextSelection == nil {
                    pdfTextSelectionLayerActive = false
                }
                if newValue.selectedOverlayID != signatureEditOverlayID {
                    signatureEditOverlayID = nil
                }
            }
            .onChange(of: signatureEditOverlayID) { _, newValue in
                if newValue != nil {
                    deactivatePDFTextSelectionLayer()
                }
            }
            .onTapGesture(count: 2) {
                guard pageZoomEnabled else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    resetZoom()
                }
            }
        }
        .ignoresSafeArea(edges: .horizontal)
    }

    @ViewBuilder
    private func pageStack(fitSize: CGSize) -> some View {
        ZStack {
            if pdfTextSelectionLayerActive || pageSelection.pdfTextSelection != nil {
                PDFPageTextSelectionView(
                    page: pdfPage,
                    pageRotation: pageRotation,
                    pageLoadKey: pageLoadKey,
                    displaySize: fitSize,
                    isInteractionEnabled: !signaturePlacementActive
                        && !textEditingActive
                        && !stickyNotePlacementActive
                        && !drawingModeActive,
                    pageSwipeEnabled: pageSwipeEnabled,
                    onPageSwipe: onPageSwipe,
                    clearSelectionToken: pdfSelectionClearToken,
                    onSelectionChange: { selection in
                        guard !signaturePlacementActive else { return }
                        if let selection {
                            pdfTextSelectionLayerActive = true
                            pageSelection = .pdfText(selection)
                        } else if case .pdfText = pageSelection {
                            pageSelection = .none
                            pdfTextSelectionLayerActive = false
                        }
                    }
                )
                .frame(width: fitSize.width, height: fitSize.height)
                .accessibilityIdentifier("pdfTextSelectionLayer")
            }

            ZStack {
                Image(uiImage: pageImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: fitSize.width, height: fitSize.height)
                    .allowsHitTesting(false)

                if !searchMatchesOnPage.isEmpty {
                    SearchHighlightCanvasLayer(
                        matches: searchMatchesOnPage,
                        activeMatchID: activeSearchMatchID,
                        pageRotation: pageRotation,
                        pageSize: fitSize
                    )
                    .frame(width: fitSize.width, height: fitSize.height)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("searchHighlightLayer")
                }

                if let stickyNote = selectedStickyNote,
                   annotationInteractionEnabled,
                   let storagePosition = stickyNote.normalizedPosition {
                    stickyNoteDragHandle(
                        noteID: stickyNote.id,
                        storagePosition: storagePosition,
                        fitSize: fitSize
                    )
                }

                if !drawingModeActive {
                    AnnotationCanvasLayer(
                        annotations: annotations,
                        pageRotation: pageRotation,
                        pageSize: fitSize,
                        selectedAnnotationID: pageSelection.selectedAnnotationID,
                        isInteractionEnabled: annotationInteractionEnabled,
                        onSelect: { annotation in
                            signatureEditOverlayID = nil
                            deactivatePDFTextSelectionLayer()
                            switch annotation.kind {
                            case .highlight:
                                pageSelection = .highlight(annotation.id)
                            case .drawing:
                                pageSelection = .drawing(annotation.id)
                            case .stickyNote:
                                pageSelection = .stickyNote(annotation.id)
                            case .textComment:
                                pageSelection = .textComment(annotation.id)
                            }
                            onSelectAnnotation(annotation)
                        }
                    )
                }

                if drawingModeActive {
                    DrawingCanvasOverlay(
                        pageRotation: pageRotation,
                        pageSize: fitSize,
                        committedStrokes: drawingCommittedStrokes,
                        sessionStrokes: drawingSessionStrokes,
                        previewStroke: drawingPreviewStroke,
                        eraserActive: drawingEraserActive,
                        onStrokeBegan: { point in onDrawingStrokeBegan(point, fitSize) },
                        onStrokeChanged: { point in onDrawingStrokeChanged(point, fitSize) },
                        onStrokeEnded: onDrawingStrokeEnded,
                        onEraseAt: { point in onDrawingEraseAt(point, fitSize) }
                    )
                }

                ForEach(sortedObjects) { object in
                    if object.isTextOverlay {
                        let isEditingThis = textEditingOverlayID == object.id
                        TextOverlayObjectView(
                            object: object,
                            pageRotation: pageRotation,
                            pageSize: fitSize,
                            canvasScale: scale,
                            isSelected: pageSelection.selectedOverlayID == object.id || isEditingThis,
                            isEditing: isEditingThis,
                            editingDraft: isEditingThis ? $textEditingDraft : nil,
                            isInteractionEnabled: !signaturePlacementActive
                                && (!textEditingActive || isEditingThis)
                                && signatureEditOverlayID == nil,
                            animatePlacement: placementAnimatingOverlayIDs.contains(object.id),
                            onPlacementAnimationFinished: {
                                onPlacementAnimationFinished(object.id)
                            },
                            onSelect: {
                                guard !signaturePlacementActive, !textEditingActive else { return }
                                signatureEditOverlayID = nil
                                deactivatePDFTextSelectionLayer()
                                pageSelection = .overlay(object.id)
                                bringToFront(object)
                            },
                            onEdit: {
                                onEditTextOverlay(object.id)
                            },
                            onEditingChanged: onTextEditingChanged,
                            onEndEditing: onEndTextEditing,
                            onUpdate: onUpdate,
                            manipulationState: overlayManipulationState
                        )
                    } else if object.usesRasterImageAsset,
                       let assetID = object.imageAssetID,
                       let overlayImage = imageProvider(assetID) {
                        ImageOverlayObjectView(
                            object: object,
                            pageRotation: pageRotation,
                            image: overlayImage,
                            pageSize: fitSize,
                            canvasScale: scale,
                            isSelected: pageSelection.selectedOverlayID == object.id,
                            isInteractionEnabled: !signaturePlacementActive
                                && !textEditingActive
                                && signatureEditOverlayID == nil,
                            animatePlacement: placementAnimatingOverlayIDs.contains(object.id),
                            onPlacementAnimationFinished: {
                                onPlacementAnimationFinished(object.id)
                            },
                            onSelect: {
                                guard !signaturePlacementActive, !textEditingActive else { return }
                                signatureEditOverlayID = nil
                                deactivatePDFTextSelectionLayer()
                                pageSelection = .overlay(object.id)
                                bringToFront(object)
                            },
                            onUpdate: onUpdate,
                            onDelete: {
                                onDelete(object.id)
                                if pageSelection.selectedOverlayID == object.id {
                                    pageSelection = .none
                                }
                            },
                            manipulationState: overlayManipulationState
                        )
                    }
                }

                Group {
                    if let textSelection = pageSelection.pdfTextSelection,
                       !signaturePlacementActive,
                       !drawingModeActive {
                        PDFTextSelectionContextMenu(
                            anchorRect: textSelection.anchorRect,
                            onCopy: { onPDFTextMenuCopy(textSelection.text) },
                            onHighlight: { onPDFTextHighlight(textSelection) },
                            onComment: { onPDFTextComment(textSelection) },
                            onMore: {}
                        )
                        .transition(.contextualGlass)
                    }

                    if let highlight = selectedHighlight, annotationInteractionEnabled {
                        HighlightContextMenu(
                            anchorPoint: AnnotationMenuEngine.anchorPoint(
                                for: highlight,
                                pageRotation: pageRotation,
                                pageSize: fitSize
                            ),
                            onColor: { color in
                                onHighlightColorChange(highlight.id, color)
                            },
                            onDelete: {
                                onDeleteAnnotation(highlight.id)
                                pageSelection = .none
                            },
                            onComment: {
                                onHighlightComment(highlight.id)
                            }
                        )
                        .transition(.contextualGlass)
                    }

                    if let stickyNote = selectedStickyNote, annotationInteractionEnabled {
                        StickyNoteContextMenu(
                            anchorPoint: AnnotationMenuEngine.anchorPoint(
                                for: stickyNote,
                                pageRotation: pageRotation,
                                pageSize: fitSize
                            ),
                            noteText: stickyNote.noteText ?? "",
                            onEdit: { onEditStickyNote(stickyNote.id) },
                            onDelete: {
                                onDeleteAnnotation(stickyNote.id)
                                pageSelection = .none
                            }
                        )
                        .transition(.contextualGlass)
                    }

                    if let comment = selectedTextComment, annotationInteractionEnabled {
                        TextCommentPopover(
                            anchorPoint: AnnotationMenuEngine.anchorPoint(
                                for: comment,
                                pageRotation: pageRotation,
                                pageSize: fitSize
                            ),
                            selectedText: comment.selectedText ?? "",
                            commentText: comment.commentText ?? "",
                            onEdit: { onEditTextComment(comment.id) },
                            onDelete: {
                                onDeleteAnnotation(comment.id)
                                pageSelection = .none
                            }
                        )
                        .transition(.contextualGlass)
                    }

                    if let drawing = selectedDrawing, annotationInteractionEnabled {
                        DrawingContextMenu(
                            anchorPoint: AnnotationMenuEngine.anchorPoint(
                                for: drawing,
                                pageRotation: pageRotation,
                                pageSize: fitSize
                            ),
                            onDelete: {
                                onDeleteAnnotation(drawing.id)
                                pageSelection = .none
                            }
                        )
                        .transition(.contextualGlass)
                    }

                    if let signature = selectedSignatureOverlay, showsSignatureContextMenu {
                        let layout = OverlayGeometryEngine.pageModeLayout(
                            for: signature,
                            pageRotation: pageRotation,
                            renderSize: fitSize
                        )
                        SignatureOverlayContextMenu(
                            anchorPoint: SignatureOverlayMenuEngine.anchorPoint(
                                for: layout,
                                pageSize: fitSize
                            ),
                            showReset: signature.signatureAppearanceDiffersFromBaseline,
                            showSaveToLibrary: signature.canSavePlacedSignatureToLibrary,
                            onEdit: {
                                withAnimation(ContextualGlassAnimation.presentation) {
                                    signatureEditOverlayID = signature.id
                                }
                            },
                            onDelete: { deleteSelectedSignature(signature.id) },
                            onReset: {
                                onResetSignatureAppearance(signature.id)
                            },
                            onSaveToLibrary: {
                                onSaveSignatureToLibrary(signature.id)
                            }
                        )
                        .transition(.contextualGlass)
                    }

                    if let textOverlay = selectedTextOverlay, showsTextContextMenu {
                        let layout = OverlayGeometryEngine.pageModeLayout(
                            for: textOverlay,
                            pageRotation: pageRotation,
                            renderSize: fitSize
                        )
                        TextOverlayContextMenu(
                            anchorPoint: TextOverlayMenuEngine.anchorPoint(
                                for: layout,
                                pageSize: fitSize
                            ),
                            onEdit: { onEditTextOverlay(textOverlay.id) },
                            onDuplicate: { onDuplicateTextOverlay(textOverlay.id) },
                            onDelete: { onDeleteTextOverlay(textOverlay.id) }
                        )
                        .transition(.contextualGlass)
                    }

                    if let editingSignature = editingSignatureOverlay {
                        let layout = OverlayGeometryEngine.pageModeLayout(
                            for: editingSignature,
                            pageRotation: pageRotation,
                            renderSize: fitSize
                        )
                        PlacedSignatureEditPopover(
                            overlay: editingSignature,
                            anchorPoint: SignatureEditPopoverEngine.anchorPoint(
                                for: layout,
                                pageSize: fitSize
                            ),
                            onSelectPresetColor: { color in
                                onUpdateSignatureAppearance(
                                    editingSignature.id,
                                    color,
                                    editingSignature.effectiveSignatureStrokeWidthPoints
                                )
                            },
                            onSelectCustomColor: { uiColor in
                                onUpdateSignatureCustomColor(
                                    editingSignature.id,
                                    uiColor,
                                    editingSignature.effectiveSignatureStrokeWidthPoints
                                )
                            },
                            onDecreaseThickness: {
                                guard let decreased = PlacedSignatureStrokeWidth.decreased(
                                    from: editingSignature.effectiveSignatureStrokeWidthPoints
                                ) else {
                                    return
                                }
                                if let custom = editingSignature.signatureCustomInkRGBA {
                                    onUpdateSignatureCustomColor(
                                        editingSignature.id,
                                        custom.uiColor,
                                        decreased
                                    )
                                } else {
                                    onUpdateSignatureAppearance(
                                        editingSignature.id,
                                        editingSignature.effectiveSignatureInkColor,
                                        decreased
                                    )
                                }
                            },
                            onIncreaseThickness: {
                                guard let increased = PlacedSignatureStrokeWidth.increased(
                                    from: editingSignature.effectiveSignatureStrokeWidthPoints
                                ) else {
                                    return
                                }
                                if let custom = editingSignature.signatureCustomInkRGBA {
                                    onUpdateSignatureCustomColor(
                                        editingSignature.id,
                                        custom.uiColor,
                                        increased
                                    )
                                } else {
                                    onUpdateSignatureAppearance(
                                        editingSignature.id,
                                        editingSignature.effectiveSignatureInkColor,
                                        increased
                                    )
                                }
                            }
                        )
                        .transition(.contextualGlass)
                    }
                }
                .animation(ContextualGlassAnimation.presentation, value: showsSignatureContextMenu)
                .animation(ContextualGlassAnimation.presentation, value: signatureEditOverlayID)
                .animation(ContextualGlassAnimation.presentation, value: pageSelection.pdfTextSelection != nil)
            }
            .id(pageLoadKey)
            .transition(.asymmetric(
                insertion: .move(edge: pageTransitionEdge),
                removal: .move(edge: pageTransitionEdge == .trailing ? .leading : .trailing)
            ))
        }
    }

    private var sortedObjects: [PageObject] {
        objects.sorted { $0.zIndex < $1.zIndex }
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard pageSwipeEnabled,
                      let direction = PageModeNavigationEngine.direction(for: value.translation) else {
                    return
                }
                onPageSwipe?(direction)
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(steadyScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                steadyScale = scale
                if scale <= minScale {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        resetZoom()
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                steadyOffset = offset
            }
    }

    private func handlePageTap(at location: CGPoint, displaySize: CGSize) {
        if signatureEditOverlayID != nil {
            signatureEditOverlayID = nil
            return
        }

        if stickyNotePlacementActive {
            guard AnnotationGeometryEngine.isDisplayTapInsidePage(location, displayPageSize: displaySize) else {
                onStickyNotePlacementDismiss?()
                return
            }
            onStickyNotePlacementTap?(location, displaySize)
            return
        }

        if textEditingActive {
            onEndTextEditing()
            return
        }

        if signaturePlacementActive {
            guard SignaturePlacementEngine.isDisplayTapInsidePage(location, displayPageSize: displaySize) else {
                return
            }
            onSignaturePlacementTap?(location, displaySize)
            return
        }

        deactivatePDFTextSelectionLayer()
        clearPageSelection()
    }

    private func handleCanvasBackgroundTap() {
        if signatureEditOverlayID != nil {
            signatureEditOverlayID = nil
            return
        }

        if stickyNotePlacementActive {
            onStickyNotePlacementDismiss?()
            return
        }

        if textEditingActive {
            onEndTextEditing()
            return
        }

        if signaturePlacementActive {
            onSignaturePlacementDismiss?()
            return
        }

        deactivatePDFTextSelectionLayer()
        clearPageSelection()
    }

    private func resetZoom() {
        scale = minScale
        steadyScale = minScale
        offset = .zero
        steadyOffset = .zero
    }

    private func bringToFront(_ object: PageObject) {
        let maxZ = objects.map(\.zIndex).max() ?? 0
        guard object.zIndex < maxZ else { return }
        var updated = object
        updated.zIndex = maxZ + 1
        onUpdate(updated)
    }

    private func clearPageSelection() {
        deactivatePDFTextSelectionLayer()
        pageSelection = .none
    }

    private func deleteSelectedSignature(_ overlayID: UUID) {
        if signatureEditOverlayID == overlayID {
            signatureEditOverlayID = nil
        }
        onDelete(overlayID)
        if pageSelection.selectedOverlayID == overlayID {
            pageSelection = .none
        }
    }

    private func deactivatePDFTextSelectionLayer() {
        pdfTextSelectionLayerActive = false
    }

    @ViewBuilder
    private func stickyNoteDragHandle(
        noteID: UUID,
        storagePosition: PageNormalizedPoint,
        fitSize: CGSize
    ) -> some View {
        let origin = stickyNoteDragOrigin ?? storagePosition
        let markerCenter = AnnotationMenuEngine.stickyNoteMarkerCenter(
            storagePosition: origin,
            pageRotation: pageRotation,
            pageSize: fitSize
        )
        let markerSize = StickyNoteStyle.markerSizeFraction * fitSize.width

        Circle()
            .fill(Color.clear)
            .frame(width: max(markerSize * 1.6, 44), height: max(markerSize * 1.6, 44))
            .contentShape(Circle())
            .position(
                x: markerCenter.x + stickyNoteDragOffset.width,
                y: markerCenter.y + stickyNoteDragOffset.height
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if stickyNoteDragOrigin == nil {
                            stickyNoteDragOrigin = storagePosition
                        }
                        stickyNoteDragOffset = value.translation
                    }
                    .onEnded { value in
                        let displayOrigin = AnnotationGeometryEngine.displayPoint(
                            from: origin,
                            pageRotation: pageRotation
                        )
                        let pixelOrigin = AnnotationGeometryEngine.pixelPoint(
                            normalizedPoint: displayOrigin,
                            renderSize: fitSize,
                            coordinateSpace: .topLeftOrigin
                        )
                        let newPixel = CGPoint(
                            x: pixelOrigin.x + value.translation.width,
                            y: pixelOrigin.y + value.translation.height
                        )
                        let normalizedDisplay = CGPoint(
                            x: newPixel.x / fitSize.width,
                            y: newPixel.y / fitSize.height
                        )
                        let clampedDisplay = AnnotationGeometryEngine.clampNormalizedPoint(normalizedDisplay)
                        let storagePoint = AnnotationGeometryEngine.storagePoint(
                            from: PageNormalizedPoint(clampedDisplay),
                            pageRotation: pageRotation
                        )
                        onMoveStickyNote(noteID, storagePoint)
                        stickyNoteDragOffset = .zero
                        stickyNoteDragOrigin = nil
                    }
            )
            .accessibilityLabel("Sticky note marker")
            .accessibilityIdentifier("stickyNoteMarker")
            .accessibilityAddTraits(.isButton)
    }

}
