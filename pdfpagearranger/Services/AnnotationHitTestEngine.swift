import CoreGraphics
import UIKit

enum AnnotationHitTestEngine {
    static func annotation(
        at displayTap: CGPoint,
        displayPageSize: CGSize,
        annotations: [PageAnnotation],
        pageRotation: Int
    ) -> PageAnnotation? {
        guard displayPageSize.width > 0, displayPageSize.height > 0 else { return nil }

        for annotation in annotations.reversed() {
            if hitTest(annotation, displayTap: displayTap, displayPageSize: displayPageSize, pageRotation: pageRotation) {
                return annotation
            }
        }
        return nil
    }

    private static func hitTest(
        _ annotation: PageAnnotation,
        displayTap: CGPoint,
        displayPageSize: CGSize,
        pageRotation: Int
    ) -> Bool {
        switch annotation.kind {
        case .highlight, .textComment:
            return rectsContain(
                displayTap,
                rects: annotation.normalizedRects ?? [],
                displayPageSize: displayPageSize,
                pageRotation: pageRotation,
                padding: annotation.kind == .textComment ? 12 : 4
            )
        case .stickyNote:
            guard let position = annotation.normalizedPosition else { return false }
            return markerContains(
                displayTap,
                position: position,
                displayPageSize: displayPageSize,
                pageRotation: pageRotation
            )
        case .drawing:
            return drawingContains(
                displayTap,
                annotation: annotation,
                displayPageSize: displayPageSize,
                pageRotation: pageRotation
            )
        }
    }

    private static func rectsContain(
        _ tap: CGPoint,
        rects: [PageNormalizedRect],
        displayPageSize: CGSize,
        pageRotation: Int,
        padding: CGFloat
    ) -> Bool {
        for storageRect in rects {
            let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: pageRotation)
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: displayRect,
                renderSize: displayPageSize,
                coordinateSpace: .topLeftOrigin
            ).insetBy(dx: -padding, dy: -padding)
            if pixelRect.contains(tap) {
                return true
            }
        }
        return false
    }

    private static func markerContains(
        _ tap: CGPoint,
        position: PageNormalizedPoint,
        displayPageSize: CGSize,
        pageRotation: Int
    ) -> Bool {
        let displayPosition = AnnotationGeometryEngine.displayPoint(from: position, pageRotation: pageRotation)
        let size = StickyNoteStyle.markerSizeFraction
        let markerRect = PageNormalizedRect(
            x: displayPosition.x - Double(size / 2),
            y: displayPosition.y - Double(size / 2),
            width: Double(size),
            height: Double(size)
        )
        let pixelRect = AnnotationGeometryEngine.pixelRect(
            normalizedRect: markerRect,
            renderSize: displayPageSize,
            coordinateSpace: .topLeftOrigin
        ).insetBy(dx: -8, dy: -8)
        return pixelRect.contains(tap)
    }

    private static func drawingContains(
        _ tap: CGPoint,
        annotation: PageAnnotation,
        displayPageSize: CGSize,
        pageRotation: Int
    ) -> Bool {
        guard let strokes = annotation.strokes else { return false }
        let threshold = max(12, displayPageSize.width * 0.02)

        for stroke in strokes {
            guard stroke.normalizedPoints.count >= 2 else { continue }
            for index in 1..<stroke.normalizedPoints.count {
                let start = pixelPoint(stroke.normalizedPoints[index - 1], displayPageSize: displayPageSize, pageRotation: pageRotation)
                let end = pixelPoint(stroke.normalizedPoints[index], displayPageSize: displayPageSize, pageRotation: pageRotation)
                if distanceFromTap(tap, toSegmentFrom: start, to: end) <= threshold {
                    return true
                }
            }
        }
        return false
    }

    static func strokeIndex(
        at displayTap: CGPoint,
        displayPageSize: CGSize,
        strokes: [DrawingStroke],
        pageRotation: Int
    ) -> Int? {
        let threshold = max(14, displayPageSize.width * 0.025)
        for (index, stroke) in strokes.enumerated().reversed() {
            guard stroke.normalizedPoints.count >= 2 else { continue }
            for pointIndex in 1..<stroke.normalizedPoints.count {
                let start = pixelPoint(stroke.normalizedPoints[pointIndex - 1], displayPageSize: displayPageSize, pageRotation: pageRotation)
                let end = pixelPoint(stroke.normalizedPoints[pointIndex], displayPageSize: displayPageSize, pageRotation: pageRotation)
                if distanceFromTap(displayTap, toSegmentFrom: start, to: end) <= threshold {
                    return index
                }
            }
        }
        return nil
    }

    private static func pixelPoint(
        _ storagePoint: PageNormalizedPoint,
        displayPageSize: CGSize,
        pageRotation: Int
    ) -> CGPoint {
        let displayPoint = AnnotationGeometryEngine.displayPoint(from: storagePoint, pageRotation: pageRotation)
        return AnnotationGeometryEngine.pixelPoint(
            normalizedPoint: displayPoint,
            renderSize: displayPageSize,
            coordinateSpace: .topLeftOrigin
        )
    }

    private static func distanceFromTap(_ tap: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(tap.x - start.x, tap.y - start.y)
        }
        let t = max(0, min(1, ((tap.x - start.x) * dx + (tap.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(tap.x - projection.x, tap.y - projection.y)
    }
}
