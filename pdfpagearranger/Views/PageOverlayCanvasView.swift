import SwiftUI

struct PageOverlayCanvasView: View {
    let pageImage: UIImage
    let pageRotation: Int
    let objects: [PageObject]
    let placementAnimatingOverlayIDs: Set<UUID>
    let onPlacementAnimationFinished: (UUID) -> Void
    @Binding var selectedObjectID: UUID?
    let imageProvider: (UUID) -> UIImage?
    let onUpdate: (PageObject) -> Void
    let onDelete: (UUID) -> Void
    let onPageSwipe: ((PageModeNavigationDirection) -> Void)?

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    @State private var overlayManipulationState = OverlayManipulationState()

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    private var pageZoomEnabled: Bool {
        selectedObjectID == nil
    }

    private var isPageZoomed: Bool {
        scale > minScale + 0.01 || offset != .zero
    }

    private var pageSwipeEnabled: Bool {
        onPageSwipe != nil
            && PageModeNavigationEngine.shouldAllowPageSwipe(
                overlayManipulationActive: overlayManipulationState.isActive,
                isPageZoomed: isPageZoomed
            )
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
                    selectedObjectID = nil
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
            Image(uiImage: pageImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: fitSize.width, height: fitSize.height)

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
                        isSelected: selectedObjectID == object.id,
                        animatePlacement: placementAnimatingOverlayIDs.contains(object.id),
                        onPlacementAnimationFinished: {
                            onPlacementAnimationFinished(object.id)
                        },
                        onSelect: {
                            selectedObjectID = object.id
                            bringToFront(object)
                        },
                        onUpdate: onUpdate,
                        onDelete: {
                            onDelete(object.id)
                            if selectedObjectID == object.id {
                                selectedObjectID = nil
                            }
                        },
                        manipulationState: overlayManipulationState
                    )
                }
            }
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

}
