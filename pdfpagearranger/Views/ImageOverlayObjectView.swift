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
    @State private var resizeScale: CGFloat = 1
    @State private var steadyResizeScale: CGFloat = 1

    private var displayGeometry: OverlayPageGeometry.Transformed {
        object.displayGeometry(pageRotation: pageRotation)
    }

    private var displaySize: CGSize {
        CGSize(
            width: displayGeometry.size.width * pageSize.width * resizeScale,
            height: displayGeometry.size.height * pageSize.height * resizeScale
        )
    }

    private var displayPosition: CGPoint {
        CGPoint(
            x: displayGeometry.position.x * pageSize.width + dragOffset.width,
            y: displayGeometry.position.y * pageSize.height + dragOffset.height
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: displaySize.width, height: displaySize.height)
                .opacity(object.opacity)
                .rotationEffect(.degrees(displayGeometry.rotation))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        resizeHandle
                    }
                }

            if isSelected {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 10, y: -10)
                .accessibilityLabel("Delete image")
            }
        }
        .position(displayPosition)
        .gesture(isSelected ? dragGesture : nil)
        .highPriorityGesture(isSelected ? resizeGesture : nil)
        .onTapGesture {
            onSelect()
        }
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 18, height: 18)
            .overlay {
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
            }
            .offset(x: 6, y: 6)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let adjusted = canvasScale > 0 ? canvasScale : 1
                dragOffset = CGSize(
                    width: value.translation.width / adjusted,
                    height: value.translation.height / adjusted
                )
            }
            .onEnded { value in
                let adjusted = canvasScale > 0 ? canvasScale : 1
                let newX = (displayGeometry.position.x * pageSize.width + value.translation.width / adjusted) / pageSize.width
                let newY = (displayGeometry.position.y * pageSize.height + value.translation.height / adjusted) / pageSize.height
                let displayPoint = CGPoint(
                    x: clamp(newX, min: 0, max: 1),
                    y: clamp(newY, min: 0, max: 1)
                )
                let stored = OverlayPageGeometry.storageTransform(
                    displayPosition: displayPoint,
                    displaySize: displayGeometry.size,
                    objectRotation: displayGeometry.rotation,
                    pageRotation: pageRotation
                )
                var updated = object
                updated.position = stored.position
                updated.size = stored.size
                updated.rotation = stored.rotation
                dragOffset = .zero
                onUpdate(updated)
            }
    }

    private var resizeGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                resizeScale = max(steadyResizeScale * value, 0.15)
            }
            .onEnded { value in
                let finalScale = max(steadyResizeScale * value, 0.15)
                let resizedDisplaySize = CGSize(
                    width: clamp(displayGeometry.size.width * finalScale, min: 0.08, max: 0.95),
                    height: clamp(displayGeometry.size.height * finalScale, min: 0.08, max: 0.95)
                )
                let stored = OverlayPageGeometry.storageTransform(
                    displayPosition: displayGeometry.position,
                    displaySize: resizedDisplaySize,
                    objectRotation: displayGeometry.rotation,
                    pageRotation: pageRotation
                )
                var updated = object
                updated.position = stored.position
                updated.size = stored.size
                updated.rotation = stored.rotation
                resizeScale = 1
                steadyResizeScale = 1
                onUpdate(updated)
            }
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
