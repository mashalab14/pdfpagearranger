import PDFKit
import SwiftUI
import UIKit

struct PageOverlayCanvasView: View {
    let pageImage: UIImage
    let pdfPage: PDFPage
    let pageRotation: Int
    let pageLoadKey: String
    let objects: [PageObject]
    let placementAnimatingOverlayIDs: Set<UUID>
    let onPlacementAnimationFinished: (UUID) -> Void
    let signaturePlacementActive: Bool
    let onSignaturePlacementTap: ((CGPoint, CGSize) -> Void)?
    let onSignaturePlacementDismiss: (() -> Void)?
    @Binding var pageSelection: PageModeSelection
    let pdfSelectionClearToken: UUID
    let imageProvider: (UUID) -> UIImage?
    let onUpdate: (PageObject) -> Void
    let onDelete: (UUID) -> Void
    let onPageSwipe: ((PageModeNavigationDirection) -> Void)?
    let onPDFTextMenuCopy: (String) -> Void
    @Binding var signatureEditOverlayID: UUID?
    let pageItemID: UUID
    let onUpdateSignatureAppearance: (UUID, SignatureInkColor, Int) -> Void
    let onUpdateSignatureCustomColor: (UUID, UIColor, Int) -> Void
    let onResetSignatureAppearance: (UUID) -> Void
    let onSaveSignatureToLibrary: (UUID) -> Void
    let pageTransitionEdge: Edge

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @State private var overlayManipulationState = OverlayManipulationState()
    @State private var pdfTextSelectionLayerActive = false

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    private var pageZoomEnabled: Bool {
        pageSelection.selectedOverlayID == nil && !signaturePlacementActive
    }

    private var isPageZoomed: Bool {
        scale > minScale + 0.01 || offset != .zero
    }

    private var pageSwipeEnabled: Bool {
        !signaturePlacementActive
            && onPageSwipe != nil
            && PageModeNavigationEngine.shouldAllowPageSwipe(
                overlayManipulationActive: overlayManipulationState.isActive,
                isPageZoomed: isPageZoomed
            )
    }

    private var selectedSignatureOverlay: PageObject? {
        guard let overlayID = pageSelection.selectedOverlayID,
              let object = objects.first(where: { $0.id == overlayID }),
              object.type == .signature else {
            return nil
        }
        return object
    }

    private var showsSignatureContextMenu: Bool {
        selectedSignatureOverlay != nil
            && signatureEditOverlayID == nil
            && !signaturePlacementActive
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
                    .offset(offset)
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
                guard !signaturePlacementActive else { return }
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
                    isInteractionEnabled: !signaturePlacementActive,
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

                ForEach(sortedObjects) { object in
                    if object.usesRasterImageAsset,
                       let assetID = object.imageAssetID,
                       let overlayImage = imageProvider(assetID) {
                        ImageOverlayObjectView(
                            object: object,
                            pageRotation: pageRotation,
                            image: overlayImage,
                            pageSize: fitSize,
                            canvasScale: scale,
                            isSelected: pageSelection.selectedOverlayID == object.id,
                            isInteractionEnabled: !signaturePlacementActive && signatureEditOverlayID == nil,
                            animatePlacement: placementAnimatingOverlayIDs.contains(object.id),
                            onPlacementAnimationFinished: {
                                onPlacementAnimationFinished(object.id)
                            },
                            onSelect: {
                                guard !signaturePlacementActive else { return }
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

                if let textSelection = pageSelection.pdfTextSelection, !signaturePlacementActive {
                    PDFTextSelectionContextMenu(
                        anchorRect: textSelection.anchorRect,
                        onCopy: { onPDFTextMenuCopy(textSelection.text) },
                        onHighlight: {},
                        onComment: {},
                        onMore: {}
                    )
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
                            signatureEditOverlayID = signature.id
                        },
                        onDelete: { deleteSelectedSignature(signature.id) },
                        onReset: {
                            onResetSignatureAppearance(signature.id)
                        },
                        onSaveToLibrary: {
                            onSaveSignatureToLibrary(signature.id)
                        }
                    )
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
                }
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

}
