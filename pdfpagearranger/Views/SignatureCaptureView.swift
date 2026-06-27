import PencilKit
import SwiftUI

struct SignatureCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let onUseSignature: (UIImage) -> Void

    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Draw your signature with your finger.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                SignatureCanvasRepresentable(canvasView: canvasView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("signatureCaptureView")

                HStack(spacing: 12) {
                    Button("Clear") {
                        canvasView.drawing = PKDrawing()
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

    private func useSignature() {
        guard let image = SignatureRenderer.image(from: canvasView.drawing) else { return }
        onUseSignature(image)
        dismiss()
    }
}

private struct SignatureCanvasRepresentable: UIViewRepresentable {
    let canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
