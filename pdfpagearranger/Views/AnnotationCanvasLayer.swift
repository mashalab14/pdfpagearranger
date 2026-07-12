import SwiftUI
import UIKit

struct AnnotationCanvasLayer: UIViewRepresentable {
    let annotations: [PageAnnotation]
    let pageRotation: Int
    let pageSize: CGSize
    let selectedAnnotationID: UUID?
    let isInteractionEnabled: Bool
    let onSelect: (PageAnnotation) -> Void

    func makeUIView(context: Context) -> AnnotationDrawingUIView {
        let view = AnnotationDrawingUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = isInteractionEnabled
        view.onSelect = onSelect
        return view
    }

    func updateUIView(_ uiView: AnnotationDrawingUIView, context: Context) {
        uiView.annotations = annotations
        uiView.pageRotation = pageRotation
        uiView.pageSize = pageSize
        uiView.selectedAnnotationID = selectedAnnotationID
        uiView.isUserInteractionEnabled = isInteractionEnabled
        uiView.onSelect = onSelect
        uiView.setNeedsDisplay()
    }
}

final class AnnotationDrawingUIView: UIView {
    var annotations: [PageAnnotation] = []
    var pageRotation: Int = 0
    var pageSize: CGSize = .zero
    var selectedAnnotationID: UUID?
    var onSelect: ((PageAnnotation) -> Void)?

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), pageSize.width > 0, pageSize.height > 0 else {
            return
        }
        AnnotationRenderer.drawAnnotations(
            annotations,
            pageRotation: pageRotation,
            renderSize: pageSize,
            in: context,
            coordinateSpace: .topLeftOrigin,
            selectedAnnotationID: selectedAnnotationID
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isUserInteractionEnabled,
              let touch = touches.first else {
            return
        }
        let location = touch.location(in: self)
        if let hit = AnnotationHitTestEngine.annotation(
            at: location,
            displayPageSize: pageSize,
            annotations: annotations,
            pageRotation: pageRotation
        ) {
            onSelect?(hit)
        }
    }
}
