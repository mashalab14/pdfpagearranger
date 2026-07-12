import CoreGraphics
import UIKit

enum SearchHighlightRenderer {
    static func drawHighlights(
        matches: [DocumentSearchMatch],
        activeMatchID: UUID?,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero
    ) {
        for match in matches {
            let isActive = match.id == activeMatchID
            drawHighlight(
                normalizedRects: match.normalizedRects,
                pageRotation: pageRotation,
                renderSize: renderSize,
                in: context,
                coordinateSpace: coordinateSpace,
                mediaBox: mediaBox,
                isActive: isActive
            )
        }
    }

    static func drawHighlight(
        normalizedRects: [PageNormalizedRect],
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero,
        isActive: Bool
    ) {
        let color = (isActive ? SearchHighlightStyle.activeFill : SearchHighlightStyle.inactiveFill).uiColor
        let opacity = isActive ? SearchHighlightStyle.activeOpacity : SearchHighlightStyle.inactiveOpacity

        context.saveGState()
        context.setFillColor(color.withAlphaComponent(opacity).cgColor)

        for storageRect in normalizedRects {
            let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: pageRotation)
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: displayRect,
                renderSize: renderSize,
                coordinateSpace: coordinateSpace,
                mediaBox: mediaBox
            )
            context.fill(pixelRect)
        }

        if isActive {
            context.setStrokeColor(UIColor.systemOrange.cgColor)
            context.setLineWidth(1.5)
            for storageRect in normalizedRects {
                let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: pageRotation)
                let pixelRect = AnnotationGeometryEngine.pixelRect(
                    normalizedRect: displayRect,
                    renderSize: renderSize,
                    coordinateSpace: coordinateSpace,
                    mediaBox: mediaBox
                )
                context.stroke(pixelRect)
            }
        }

        context.restoreGState()
    }
}
