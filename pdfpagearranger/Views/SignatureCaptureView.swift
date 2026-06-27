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

                    Button("Use Signature") {
                        useSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasDrawing)
                    .accessibilityIdentifier("signatureUseButton")
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
        HStack(spacing: 20) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(SignatureInkColor.allCases) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color.displayColor)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    selectedColor == color ? Color.accentColor : Color(.separator),
                                    lineWidth: selectedColor == color ? 2.5 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue)
                .accessibilityIdentifier(color.accessibilityIdentifier)
            }

            Spacer()
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
