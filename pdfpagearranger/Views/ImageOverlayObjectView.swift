import SwiftUI

struct ImageOverlayObjectView: View {
    let object: PageObject
    let pageRotation: Int
    let image: UIImage
    let pageSize: CGSize
    let canvasScale: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onUpdate: (PageObject) -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var dragOriginCenter: CGPoint?
    @State private var resizeScale: CGFloat = 1
    @State private var steadyResizeScale: CGFloat = 1
    @State private var resizeStartLayoutSize: CGSize?

    private var layout: OverlayGeometryEngine.Layout {
        OverlayGeometryEngine.pageModeLayout(
            for: object,
            pageRotation: pageRotation,
            renderSize: pageSize
        )
    }

    private var displayGeometry: OverlayGeometryEngine.NormalizedGeometry {
        object.displayGeometry(pageRotation: pageRotation)
    }

    private var activeLayoutSize: CGSize {
        CGSize(
            width: layout.size.width * resizeScale,
            height: layout.size.height * resizeScale
        )
    }

    private var displayPosition: CGPoint {
        let origin = dragOriginCenter ?? layout.center
        return CGPoint(
            x: origin.x + dragOffset.width,
            y: origin.y + dragOffset.height
        )
    }

    private var minLayoutSize: CGSize {
        CGSize(
            width: OverlayInteractionEngine.minNormalizedSize * pageSize.width,
            height: OverlayInteractionEngine.minNormalizedSize * pageSize.height
        )
    }

    private var maxLayoutSize: CGSize {
        CGSize(
            width: OverlayInteractionEngine.maxNormalizedSize * pageSize.width,
            height: OverlayInteractionEngine.maxNormalizedSize * pageSize.height
        )
    }

    var body: some View {
        overlayImage
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    deleteButton
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    resizeHandle
                }
            }
            .position(displayPosition)
            .gesture(isSelected ? dragGesture : nil)
            .simultaneousGesture(isSelected ? magnificationGesture : nil)
            .onTapGesture {
                onSelect()
            }
            .onChange(of: isSelected) { _, selected in
                if !selected {
                    resetTransientGestureState()
                }
            }
            .onChange(of: object.id) { _, _ in
                resetTransientGestureState()
            }
    }

    private var overlayImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: activeLayoutSize.width, height: activeLayoutSize.height)
            .opacity(object.opacity)
            .rotationEffect(.degrees(layout.rotationDegrees))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
        }
        .offset(x: 10, y: -10)
        .accessibilityLabel("Delete image")
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 22, height: 22)
            .overlay {
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
            }
            .padding(10)
            .contentShape(Rectangle())
            .offset(x: 8, y: 8)
            .accessibilityIdentifier("overlayResizeHandle")
            .highPriorityGesture(resizeHandleGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragOriginCenter == nil {
                    dragOriginCenter = layout.center
                }

                let adjustedScale = max(canvasScale, 0.01)
                dragOffset = CGSize(
                    width: value.translation.width / adjustedScale,
                    height: value.translation.height / adjustedScale
                )
            }
            .onEnded { value in
                let startCenter = dragOriginCenter ?? layout.center
                let finalCenter = OverlayInteractionEngine.dragDisplayCenter(
                    startCenter: startCenter,
                    translation: value.translation,
                    canvasScale: canvasScale
                )
                let displayPoint = OverlayInteractionEngine.clampNormalizedPoint(
                    CGPoint(
                        x: finalCenter.x / pageSize.width,
                        y: finalCenter.y / pageSize.height
                    )
                )

                commitGeometryUpdate(
                    displayPosition: displayPoint,
                    displaySize: currentDisplayNormalizedSize()
                )

                dragOffset = .zero
                dragOriginCenter = nil
            }
    }

    private var resizeHandleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if resizeStartLayoutSize == nil {
                    resizeStartLayoutSize = layout.size
                }

                guard let startLayoutSize = resizeStartLayoutSize else { return }

                let resized = OverlayInteractionEngine.uniformResizedLayoutSize(
                    startSize: startLayoutSize,
                    translation: value.translation,
                    canvasScale: canvasScale,
                    minSize: minLayoutSize,
                    maxSize: maxLayoutSize
                )

                resizeScale = resized.width / max(startLayoutSize.width, 0.01)
            }
            .onEnded { value in
                guard let startLayoutSize = resizeStartLayoutSize else {
                    resetResizeState()
                    return
                }

                let resized = OverlayInteractionEngine.uniformResizedLayoutSize(
                    startSize: startLayoutSize,
                    translation: value.translation,
                    canvasScale: canvasScale,
                    minSize: minLayoutSize,
                    maxSize: maxLayoutSize
                )

                let finalDisplaySize = CGSize(
                    width: resized.width / max(pageSize.width, 0.01),
                    height: resized.height / max(pageSize.height, 0.01)
                )

                commitGeometryUpdate(
                    displayPosition: displayGeometry.position,
                    displaySize: finalDisplaySize
                )

                resetResizeState()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                resizeScale = max(steadyResizeScale * value, OverlayInteractionEngine.minMagnificationScale)
            }
            .onEnded { value in
                let finalScale = max(steadyResizeScale * value, OverlayInteractionEngine.minMagnificationScale)
                let finalDisplaySize = OverlayInteractionEngine.magnificationResizedNormalizedSize(
                    startNormalizedSize: displayGeometry.size,
                    magnification: finalScale
                )

                commitGeometryUpdate(
                    displayPosition: displayGeometry.position,
                    displaySize: finalDisplaySize
                )

                resetResizeState()
            }
    }

    private func currentDisplayNormalizedSize() -> CGSize {
        CGSize(
            width: activeLayoutSize.width / max(pageSize.width, 0.01),
            height: activeLayoutSize.height / max(pageSize.height, 0.01)
        )
    }

    private func commitGeometryUpdate(displayPosition: CGPoint, displaySize: CGSize) {
        let stored = OverlayGeometryEngine.storageGeometry(
            displayPosition: displayPosition,
            displaySize: displaySize,
            objectRotation: displayGeometry.rotation,
            pageRotation: pageRotation
        )
        var updated = object
        updated.position = stored.position
        updated.size = stored.size
        updated.rotation = stored.rotation
        onUpdate(updated)
    }

    private func resetResizeState() {
        resizeScale = 1
        steadyResizeScale = 1
        resizeStartLayoutSize = nil
    }

    private func resetTransientGestureState() {
        dragOffset = .zero
        dragOriginCenter = nil
        resetResizeState()
    }
}
