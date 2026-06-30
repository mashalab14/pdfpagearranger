import PDFKit
import SwiftUI

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
    @Binding var pageSelection: PageModeSelection
    let pdfSelectionClearToken: UUID
    let imageProvider: (UUID) -> UIImage?
    let onUpdate: (PageObject) -> Void
    let onDelete: (UUID) -> Void
    let onPageSwipe: ((PageModeNavigationDirection) -> Void)?
    let onPDFTextMenuCopy: (String) -> Void
    let onEditSignature: (UUID) -> Void
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
            && !signaturePlacementActive
            && !overlayManipulationState.isActive
    }

    var body: some View {
        GeometryReader { geometry in
            let displaySize = PageModeLayoutSizing.displaySize(
                imageSize: pageImage.size,
                containerSize: geometry.size,
                leadingSafeAreaInset: geometry.safeAreaInsets.leading,
                trailingSafeAreaInset: geometry.safeAreaInsets.trailing
            )

            pageStack(fitSize: displaySize)
                .frame(width: displaySize.width, height: displaySize.height)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(pageZoomEnabled ? magnificationGesture : nil)
                .simultaneousGesture(pageZoomEnabled ? panGesture : nil)
                .simultaneousGesture(pageSwipeEnabled ? pageSwipeGesture : nil)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("pageModeCanvas")
                .onTapGesture {
                    guard !signaturePlacementActive else { return }
                    deactivatePDFTextSelectionLayer()
                    clearPageSelection()
                }
                .onLongPressGesture(minimumDuration: 0.35) {
                    guard !signaturePlacementActive else { return }
                    pdfTextSelectionLayerActive = true
                }
                .onTapGesture(coordinateSpace: .local) { location in
                    guard signaturePlacementActive else { return }
                    onSignaturePlacementTap?(location, displaySize)
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
                            isInteractionEnabled: !signaturePlacementActive,
                            animatePlacement: placementAnimatingOverlayIDs.contains(object.id),
                            onPlacementAnimationFinished: {
                                onPlacementAnimationFinished(object.id)
                            },
                            onSelect: {
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

                if let textSelection = pageSelection.pdfTextSelection {
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
                        onEdit: { onEditSignature(signature.id) },
                        onDelete: { deleteSelectedSignature(signature.id) }
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
        onDelete(overlayID)
        if pageSelection.selectedOverlayID == overlayID {
            pageSelection = .none
        }
    }

    private func deactivatePDFTextSelectionLayer() {
        pdfTextSelectionLayerActive = false
    }

}
