import PencilKit
import SwiftUI

struct SignatureCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let onUseSignature: (UIImage) -> Void

    @State private var selectedColor: SignatureInkColor = .defaultInk
    @State private var hasDrawing = false
    @State private var canvasView: PKCanvasView?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Draw your signature with your finger.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                SignatureCanvasRepresentable(
                    selectedColor: selectedColor,
                    hasDrawing: $hasDrawing,
                    canvasView: $canvasView
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal)
                .accessibilityIdentifier("signatureCaptureView")

                signatureColorPicker
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Clear") {
                        clearDrawing()
                    }
                    .accessibilityIdentifier("signatureClearButton")

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }

                    Button("Save & Use") {
                        useSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasDrawing)
                    .accessibilityIdentifier("signatureSaveAndUseButton")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var signatureColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(SignatureInkColor.allCases) { color in
                        colorSwatch(for: color)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func colorSwatch(for color: SignatureInkColor) -> some View {
        Button {
            selectedColor = color
        } label: {
            ZStack {
                Circle()
                    .fill(color.displayColor)
                    .frame(width: 30, height: 30)

                if selectedColor == color {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .frame(width: 38, height: 38)

                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(checkmarkColor(for: color))
                }
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.rawValue)
        .accessibilityIdentifier(color.accessibilityIdentifier)
    }

    private func checkmarkColor(for color: SignatureInkColor) -> Color {
        switch color {
        case .black, .darkGray, .blue, .purple:
            return .white
        case .red, .green:
            return .white
        }
    }

    private func clearDrawing() {
        canvasView?.drawing = PKDrawing()
        hasDrawing = false
    }

    private func useSignature() {
        guard hasDrawing,
              let canvasView,
              let image = SignatureRenderer.image(from: canvasView.drawing) else {
            return
        }
        onUseSignature(image)
        dismiss()
    }
}

private struct SignatureCanvasRepresentable: UIViewRepresentable {
    let selectedColor: SignatureInkColor
    @Binding var hasDrawing: Bool
    @Binding var canvasView: PKCanvasView?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.overrideUserInterfaceStyle = .light
        context.coordinator.applyInkColor(selectedColor, to: canvas)

        DispatchQueue.main.async {
            canvasView = canvas
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyInkColor(selectedColor, to: uiView)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SignatureCanvasRepresentable

        init(parent: SignatureCanvasRepresentable) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.hasDrawing = !canvasView.drawing.bounds.isEmpty
        }

        func applyInkColor(_ color: SignatureInkColor, to canvasView: PKCanvasView) {
            canvasView.tool = PKInkingTool(.pen, color: color.uiColor, width: 2.5)
        }
    }
}
