import SwiftUI
import UIKit

struct DrawingCanvasOverlay: UIViewRepresentable {
    let pageRotation: Int
    let pageSize: CGSize
    let committedStrokes: [DrawingStroke]
    let sessionStrokes: [DrawingStroke]
    let previewStroke: DrawingStroke?
    let eraserActive: Bool
    let onStrokeBegan: (CGPoint) -> Void
    let onStrokeChanged: (CGPoint) -> Void
    let onStrokeEnded: () -> Void
    let onEraseAt: (CGPoint) -> Void

    func makeUIView(context: Context) -> DrawingOverlayUIView {
        let view = DrawingOverlayUIView()
        view.backgroundColor = .clear
        view.onStrokeBegan = onStrokeBegan
        view.onStrokeChanged = onStrokeChanged
        view.onStrokeEnded = onStrokeEnded
        view.onEraseAt = onEraseAt
        return view
    }

    func updateUIView(_ uiView: DrawingOverlayUIView, context: Context) {
        uiView.pageRotation = pageRotation
        uiView.pageSize = pageSize
        uiView.committedStrokes = committedStrokes
        uiView.sessionStrokes = sessionStrokes
        uiView.previewStroke = previewStroke
        uiView.eraserActive = eraserActive
        uiView.onStrokeBegan = onStrokeBegan
        uiView.onStrokeChanged = onStrokeChanged
        uiView.onStrokeEnded = onStrokeEnded
        uiView.onEraseAt = onEraseAt
        uiView.setNeedsDisplay()
    }
}

final class DrawingOverlayUIView: UIView {
    var pageRotation: Int = 0
    var pageSize: CGSize = .zero
    var committedStrokes: [DrawingStroke] = []
    var sessionStrokes: [DrawingStroke] = []
    var previewStroke: DrawingStroke?
    var eraserActive = false
    var onStrokeBegan: ((CGPoint) -> Void)?
    var onStrokeChanged: ((CGPoint) -> Void)?
    var onStrokeEnded: (() -> Void)?
    var onEraseAt: ((CGPoint) -> Void)?

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), pageSize.width > 0 else { return }
        var strokes = committedStrokes + sessionStrokes
        if let previewStroke {
            strokes.append(previewStroke)
        }
        guard !strokes.isEmpty else { return }

        let annotation = PageAnnotation(pageItemID: UUID(), kind: .drawing, strokes: strokes)
        AnnotationRenderer.drawDrawing(
            annotation,
            pageRotation: pageRotation,
            renderSize: pageSize,
            in: context,
            coordinateSpace: .topLeftOrigin
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if eraserActive {
            onEraseAt?(point)
        } else {
            onStrokeBegan?(point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if eraserActive {
            onEraseAt?(point)
        } else {
            onStrokeChanged?(point)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if eraserActive {
            setNeedsDisplay()
            return
        }
        onStrokeEnded?()
        setNeedsDisplay()
    }
}

struct DrawingModeToolbar: View {
    @Binding var selectedColor: DrawingPresetColor
    @Binding var selectedThickness: DrawingThicknessPreset
    @Binding var eraserActive: Bool
    let canUndoStroke: Bool
    let canClear: Bool
    let onUndoStroke: () -> Void
    let onClear: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DrawingPresetColor.allCases, id: \.self) { color in
                    Button {
                        selectedColor = color
                        eraserActive = false
                        DrawingSettings.setStoredColor(color)
                    } label: {
                        Circle()
                            .fill(Color(color.rgba.uiColor))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if selectedColor == color && !eraserActive {
                                    Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(color.rawValue) pen color")
                    .accessibilityIdentifier("drawingColor_\(color.rawValue)")
                }

                ForEach(DrawingThicknessPreset.allCases, id: \.self) { thickness in
                    let isSelected = selectedThickness == thickness && !eraserActive
                    Button(thickness.label) {
                        selectedThickness = thickness
                        eraserActive = false
                        DrawingSettings.setStoredThickness(thickness)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityIdentifier("drawingThickness_\(thickness.rawValue)")
                }

                Button {
                    eraserActive.toggle()
                } label: {
                    Label("Eraser", systemImage: "eraser")
                }
                .buttonStyle(.bordered)
                .tint(eraserActive ? Color.accentColor : Color.secondary)
                .accessibilityIdentifier("drawingEraserButton")

                Button("Undo Stroke", action: onUndoStroke)
                    .buttonStyle(.bordered)
                    .disabled(!canUndoStroke)
                    .accessibilityIdentifier("drawingUndoStrokeButton")

                Button("Clear", action: onClear)
                    .buttonStyle(.bordered)
                    .disabled(!canClear)
                    .accessibilityIdentifier("drawingClearButton")

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("drawingDoneButton")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .accessibilityIdentifier("drawingModeToolbar")
    }
}

private extension DrawingThicknessPreset {
    var label: String {
        switch self {
        case .thin: "Thin"
        case .medium: "Medium"
        case .thick: "Thick"
        }
    }
}

enum DrawingStrokeBuilder {
    static func appendPoint(
        displayPoint: CGPoint,
        displayPageSize: CGSize,
        pageRotation: Int,
        to points: inout [PageNormalizedPoint]
    ) {
        guard AnnotationGeometryEngine.isDisplayTapInsidePage(displayPoint, displayPageSize: displayPageSize),
              let storagePoint = AnnotationGeometryEngine.displayTapToStoragePoint(
                tap: displayPoint,
                displayPageSize: displayPageSize,
                pageRotation: pageRotation
              ) else {
            return
        }

        if let last = points.last {
            let dx = storagePoint.x - last.x
            let dy = storagePoint.y - last.y
            if (dx * dx + dy * dy) < 0.0000004 {
                return
            }
        }
        points.append(storagePoint)
    }

    static func makeStroke(
        from points: [PageNormalizedPoint],
        color: DrawingPresetColor,
        thickness: DrawingThicknessPreset
    ) -> DrawingStroke? {
        guard points.count >= 2 else { return nil }
        return DrawingStroke(
            normalizedPoints: points,
            colorRGBA: color.rgba,
            normalizedLineWidth: Double(thickness.normalizedWidth)
        )
    }
}
