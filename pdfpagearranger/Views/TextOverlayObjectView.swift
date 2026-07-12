import SwiftUI
import UIKit

struct TextOverlayObjectView: View {
    let object: PageObject
    let pageRotation: Int
    let pageSize: CGSize
    let canvasScale: CGFloat
    let isSelected: Bool
    var isInteractionEnabled: Bool = true
    let animatePlacement: Bool
    let onPlacementAnimationFinished: (() -> Void)?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onUpdate: (PageObject) -> Void
    let manipulationState: OverlayManipulationState

    @State private var dragOffset: CGSize = .zero
    @State private var dragOriginCenter: CGPoint?
    @State private var resizeScale: CGSize = CGSize(width: 1, height: 1)
    @State private var resizeStartLayoutSize: CGSize?
    @State private var rotationDelta: CGFloat = 0
    @State private var isRotating = false
    @State private var placementReveal: CGFloat = 1
    @State private var didStartPlacementAnimation = false

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
            width: layout.size.width * resizeScale.width,
            height: layout.size.height * resizeScale.height
        )
    }

    private var activeRotationDegrees: CGFloat {
        layout.rotationDegrees + rotationDelta
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
            width: TextOverlayLayoutEngine.minWidthFraction * pageSize.width,
            height: TextOverlayLayoutEngine.minHeightFraction * pageSize.height
        )
    }

    private var maxLayoutSize: CGSize {
        CGSize(
            width: TextOverlayLayoutEngine.maxWidthFraction * pageSize.width,
            height: TextOverlayLayoutEngine.maxHeightFraction * pageSize.height
        )
    }

    var body: some View {
        textContent
            .opacity(Double(object.opacity * placementReveal))
            .scaleEffect(OverlayPlacementAnimation.scale(for: placementReveal))
            .position(displayPosition)
            .gesture(isSelected && isInteractionEnabled ? dragGesture : nil)
            .onTapGesture(count: 2) {
                guard isInteractionEnabled else { return }
                onEdit()
            }
            .onTapGesture {
                guard isInteractionEnabled else { return }
                onSelect()
            }
            .allowsHitTesting(isInteractionEnabled)
            .onAppear { startPlacementAnimationIfNeeded() }
            .onChange(of: animatePlacement) { _, shouldAnimate in
                if shouldAnimate {
                    startPlacementAnimationIfNeeded()
                } else {
                    placementReveal = 1
                    didStartPlacementAnimation = false
                }
            }
            .onChange(of: isSelected) { _, selected in
                if !selected { resetTransientGestureState() }
            }
            .onChange(of: object.id) { _, _ in
                resetTransientGestureState()
                placementReveal = 1
                didStartPlacementAnimation = false
            }
    }

    private var textContent: some View {
        ZStack {
            TextOverlayLabelView(object: object, layoutHeight: activeLayoutSize.height)
                .frame(width: activeLayoutSize.width, height: activeLayoutSize.height, alignment: .topLeading)
                .rotationEffect(.degrees(activeRotationDegrees))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())

            if isSelected {
                rotateHandle
            }
            if isSelected {
                resizeHandle
            }
        }
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 22, height: 22)
            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
            .padding(10)
            .contentShape(Rectangle())
            .offset(x: activeLayoutSize.width / 2 + 8, y: activeLayoutSize.height / 2 + 8)
            .accessibilityIdentifier("textOverlayResizeHandle")
            .highPriorityGesture(resizeHandleGesture)
    }

    private var rotateHandle: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            .padding(10)
            .contentShape(Rectangle())
            .offset(x: -activeLayoutSize.width / 2 - 8, y: -activeLayoutSize.height / 2 - 8)
            .accessibilityLabel("Rotate Text")
            .accessibilityIdentifier("textOverlayRotateHandle")
            .highPriorityGesture(rotateHandleGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                manipulationState.begin()
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
                let displayPoint = CGPoint(
                    x: finalCenter.x / pageSize.width,
                    y: finalCenter.y / pageSize.height
                )
                commitGeometryUpdate(
                    displayPosition: displayPoint,
                    displaySize: currentDisplayNormalizedSize(),
                    rotationDegrees: activeRotationDegrees
                )
                dragOffset = .zero
                dragOriginCenter = nil
                manipulationState.end()
            }
    }

    private var resizeHandleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                manipulationState.begin()
                if resizeStartLayoutSize == nil {
                    resizeStartLayoutSize = layout.size
                }
                guard let startLayoutSize = resizeStartLayoutSize else { return }
                let resized = OverlayInteractionEngine.nonUniformResizedLayoutSize(
                    startSize: startLayoutSize,
                    translation: value.translation,
                    canvasScale: canvasScale,
                    minSize: minLayoutSize,
                    maxSize: maxLayoutSize
                )
                resizeScale = CGSize(
                    width: resized.width / max(startLayoutSize.width, 0.01),
                    height: resized.height / max(startLayoutSize.height, 0.01)
                )
            }
            .onEnded { value in
                guard let startLayoutSize = resizeStartLayoutSize else {
                    resetResizeState()
                    return
                }
                let resized = OverlayInteractionEngine.nonUniformResizedLayoutSize(
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
                    displayPosition: currentDisplayNormalizedPosition(),
                    displaySize: TextOverlayBoundsEngine.clampDisplaySize(finalDisplaySize),
                    rotationDegrees: activeRotationDegrees
                )
                resetResizeState()
                manipulationState.end()
            }
    }

    private var rotateHandleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                manipulationState.begin()
                if !isRotating {
                    isRotating = true
                }
                let center = displayPosition
                let start = CGVector(
                    dx: center.x - value.startLocation.x,
                    dy: center.y - value.startLocation.y
                )
                let current = CGVector(
                    dx: center.x - value.location.x,
                    dy: center.y - value.location.y
                )
                rotationDelta = OverlayInteractionEngine.rotationAngle(
                    center: center,
                    startVector: start,
                    currentVector: current
                )
            }
            .onEnded { _ in
                commitGeometryUpdate(
                    displayPosition: currentDisplayNormalizedPosition(),
                    displaySize: currentDisplayNormalizedSize(),
                    rotationDegrees: activeRotationDegrees
                )
                rotationDelta = 0
                isRotating = false
                manipulationState.end()
            }
    }

    private func currentDisplayNormalizedSize() -> CGSize {
        TextOverlayBoundsEngine.clampDisplaySize(
            CGSize(
                width: activeLayoutSize.width / max(pageSize.width, 0.01),
                height: activeLayoutSize.height / max(pageSize.height, 0.01)
            )
        )
    }

    private func currentDisplayNormalizedPosition() -> CGPoint {
        TextOverlayBoundsEngine.clampDisplayCenter(
            CGPoint(
                x: displayPosition.x / pageSize.width,
                y: displayPosition.y / pageSize.height
            ),
            displaySize: currentDisplayNormalizedSize(),
            rotationDegrees: activeRotationDegrees
        )
    }

    private func commitGeometryUpdate(
        displayPosition: CGPoint,
        displaySize: CGSize,
        rotationDegrees: CGFloat
    ) {
        let clampedCenter = TextOverlayBoundsEngine.clampDisplayCenter(
            displayPosition,
            displaySize: displaySize,
            rotationDegrees: rotationDegrees
        )
        let stored = OverlayGeometryEngine.storageGeometry(
            displayPosition: clampedCenter,
            displaySize: displaySize,
            objectRotation: rotationDegrees,
            pageRotation: pageRotation
        )
        var updated = object
        updated.position = stored.position
        updated.size = stored.size
        updated.rotation = stored.rotation
        onUpdate(updated)
    }

    private func resetResizeState() {
        resizeScale = CGSize(width: 1, height: 1)
        resizeStartLayoutSize = nil
    }

    private func resetTransientGestureState() {
        dragOffset = .zero
        dragOriginCenter = nil
        resetResizeState()
        rotationDelta = 0
        isRotating = false
    }

    private func startPlacementAnimationIfNeeded() {
        guard animatePlacement, !didStartPlacementAnimation else {
            if !animatePlacement { placementReveal = 1 }
            return
        }
        didStartPlacementAnimation = true
        placementReveal = 0
        withAnimation(.easeOut(duration: OverlayPlacementAnimation.duration)) {
            placementReveal = 1
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(OverlayPlacementAnimation.duration * 1_000_000_000))
            onPlacementAnimationFinished?()
        }
    }
}

private struct TextOverlayLabelView: View {
    let object: PageObject
    let layoutHeight: CGFloat

    var body: some View {
        let renderScale = TextOverlayLayoutEngine.renderScale(
            for: layoutHeight,
            normalizedHeight: object.size.height
        )
        let attributed = TextOverlayLayoutEngine.attributedString(
            for: object,
            renderScale: renderScale
        )
        Text(AttributedString(attributed))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .multilineTextAlignment(.leading)
    }
}
