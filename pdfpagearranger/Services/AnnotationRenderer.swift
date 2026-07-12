import CoreGraphics
import UIKit

enum AnnotationRenderer {
    static func drawAnnotations(
        _ annotations: [PageAnnotation],
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero,
        selectedAnnotationID: UUID? = nil
    ) {
        for annotation in annotations.sorted(by: { $0.createdAt < $1.createdAt }) {
            let isSelected = annotation.id == selectedAnnotationID
            switch annotation.kind {
            case .highlight:
                drawHighlight(
                    annotation,
                    pageRotation: pageRotation,
                    renderSize: renderSize,
                    in: context,
                    coordinateSpace: coordinateSpace,
                    mediaBox: mediaBox,
                    isSelected: isSelected
                )
            case .drawing:
                drawDrawing(
                    annotation,
                    pageRotation: pageRotation,
                    renderSize: renderSize,
                    in: context,
                    coordinateSpace: coordinateSpace,
                    mediaBox: mediaBox,
                    isSelected: isSelected
                )
            case .textComment:
                drawTextComment(
                    annotation,
                    pageRotation: pageRotation,
                    renderSize: renderSize,
                    in: context,
                    coordinateSpace: coordinateSpace,
                    mediaBox: mediaBox,
                    isSelected: isSelected
                )
            case .stickyNote:
                drawStickyNote(
                    annotation,
                    pageRotation: pageRotation,
                    renderSize: renderSize,
                    in: context,
                    coordinateSpace: coordinateSpace,
                    mediaBox: mediaBox,
                    isSelected: isSelected
                )
            }
        }
    }

    static func drawHighlight(
        _ annotation: PageAnnotation,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero,
        isSelected: Bool = false
    ) {
        guard let rects = annotation.normalizedRects, !rects.isEmpty else { return }
        let color = (annotation.highlightColor ?? .defaultPreset).rgba.uiColor
        let opacity = annotation.highlightOpacity ?? Double(HighlightPresetColor.defaultOpacity)

        context.saveGState()
        context.setFillColor(color.withAlphaComponent(CGFloat(opacity)).cgColor)

        for storageRect in rects {
            let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: pageRotation)
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: displayRect,
                renderSize: renderSize,
                coordinateSpace: coordinateSpace,
                mediaBox: mediaBox
            )
            context.fill(pixelRect)
        }

        if isSelected {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(2)
            for storageRect in rects {
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

    static func drawDrawing(
        _ annotation: PageAnnotation,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero,
        isSelected: Bool = false
    ) {
        guard let strokes = annotation.strokes else { return }

        for stroke in strokes {
            guard stroke.normalizedPoints.count >= 2 else { continue }
            let color = stroke.colorRGBA.uiColor.withAlphaComponent(CGFloat(stroke.opacity))

            context.saveGState()
            context.setStrokeColor(color.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let lineWidth = stroke.normalizedLineWidth * Double(renderSize.width)
            context.setLineWidth(CGFloat(lineWidth))

            let path = CGMutablePath()
            for (index, storagePoint) in stroke.normalizedPoints.enumerated() {
                let displayPoint = AnnotationGeometryEngine.displayPoint(from: storagePoint, pageRotation: pageRotation)
                let pixelPoint = AnnotationGeometryEngine.pixelPoint(
                    normalizedPoint: displayPoint,
                    renderSize: renderSize,
                    coordinateSpace: coordinateSpace,
                    mediaBox: mediaBox
                )
                if index == 0 {
                    path.move(to: pixelPoint)
                } else {
                    path.addLine(to: pixelPoint)
                }
            }
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
        }

        if isSelected, let bounds = drawingBounds(for: annotation, pageRotation: pageRotation) {
            context.saveGState()
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(2)
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: bounds,
                renderSize: renderSize,
                coordinateSpace: coordinateSpace,
                mediaBox: mediaBox
            )
            context.stroke(pixelRect.insetBy(dx: -4, dy: -4))
            context.restoreGState()
        }
    }

    static func drawTextComment(
        _ annotation: PageAnnotation,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero,
        isSelected: Bool = false
    ) {
        guard let rects = annotation.normalizedRects, !rects.isEmpty else { return }
        let anchorColor = (annotation.anchorColorRGBA ?? TextCommentStyle.defaultAnchorColor).uiColor

        context.saveGState()
        context.setFillColor(anchorColor.withAlphaComponent(TextCommentStyle.anchorOpacity).cgColor)
        for storageRect in rects {
            let displayRect = AnnotationGeometryEngine.displayRect(from: storageRect, pageRotation: pageRotation)
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: displayRect,
                renderSize: renderSize,
                coordinateSpace: coordinateSpace,
                mediaBox: mediaBox
            )
            context.fill(pixelRect)
        }
        context.restoreGState()

        if let anchor = markerAnchor(for: annotation, pageRotation: pageRotation) {
            drawCommentMarker(
                at: anchor,
                pageRotation: pageRotation,
                renderSize: renderSize,
                in: context,
                coordinateSpace: coordinateSpace,
                mediaBox: mediaBox,
                isSelected: isSelected
            )
        }
    }

    static func drawStickyNote(
        _ annotation: PageAnnotation,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect = .zero,
        isSelected: Bool = false
    ) {
        guard let position = annotation.normalizedPosition else { return }
        drawStickyNoteMarker(
            at: position,
            pageRotation: pageRotation,
            renderSize: renderSize,
            in: context,
            coordinateSpace: coordinateSpace,
            mediaBox: mediaBox,
            noteColor: (annotation.noteColorRGBA ?? StickyNoteStyle.defaultColor).uiColor,
            isSelected: isSelected
        )
    }

    static func markerAnchor(for annotation: PageAnnotation, pageRotation: Int) -> PageNormalizedPoint? {
        guard let rects = annotation.normalizedRects else { return nil }
        let displayRects = AnnotationGeometryEngine.displayRects(from: rects, pageRotation: pageRotation)
        guard let union = AnnotationGeometryEngine.unionAnchorRect(for: displayRects) else { return nil }
        return PageNormalizedPoint(
            x: union.x + union.width,
            y: max(0, union.y - StickyNoteStyle.markerSizeFraction * 0.5)
        )
    }

    static func drawingBounds(for annotation: PageAnnotation, pageRotation: Int) -> PageNormalizedRect? {
        guard let strokes = annotation.strokes else { return nil }
        var union: CGRect = .null
        for stroke in strokes {
            for point in stroke.normalizedPoints {
                let displayPoint = AnnotationGeometryEngine.displayPoint(from: point, pageRotation: pageRotation)
                let rect = CGRect(x: displayPoint.x, y: displayPoint.y, width: 0.001, height: 0.001)
                union = union.isNull ? rect : union.union(rect)
            }
        }
        guard !union.isNull else { return nil }
        return PageNormalizedRect(union.insetBy(dx: -0.01, dy: -0.01))
    }

    private static func drawCommentMarker(
        at anchor: PageNormalizedPoint,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect,
        isSelected: Bool
    ) {
        let size = StickyNoteStyle.markerSizeFraction
        let markerRect = PageNormalizedRect(
            x: anchor.x,
            y: anchor.y,
            width: Double(size),
            height: Double(size)
        )
        drawMarkerIcon(
            in: markerRect,
            pageRotation: pageRotation,
            renderSize: renderSize,
            in: context,
            coordinateSpace: coordinateSpace,
            mediaBox: mediaBox,
            fillColor: TextCommentStyle.defaultAnchorColor.uiColor,
            isSelected: isSelected
        )
    }

    private static func drawStickyNoteMarker(
        at storagePosition: PageNormalizedPoint,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect,
        noteColor: UIColor,
        isSelected: Bool
    ) {
        let displayPosition = AnnotationGeometryEngine.displayPoint(from: storagePosition, pageRotation: pageRotation)
        let size = StickyNoteStyle.markerSizeFraction
        let markerRect = PageNormalizedRect(
            x: displayPosition.x - Double(size / 2),
            y: displayPosition.y - Double(size / 2),
            width: Double(size),
            height: Double(size)
        )
        drawMarkerIcon(
            in: markerRect,
            pageRotation: pageRotation,
            renderSize: renderSize,
            in: context,
            coordinateSpace: coordinateSpace,
            mediaBox: mediaBox,
            fillColor: noteColor,
            isSelected: isSelected
        )
    }

    private static func drawMarkerIcon(
        in normalizedRect: PageNormalizedRect,
        pageRotation: Int,
        renderSize: CGSize,
        in context: CGContext,
        coordinateSpace: AnnotationGeometryEngine.CoordinateSpace,
        mediaBox: CGRect,
        fillColor: UIColor,
        isSelected: Bool
    ) {
        let pixelRect = AnnotationGeometryEngine.pixelRect(
            normalizedRect: normalizedRect,
            renderSize: renderSize,
            coordinateSpace: coordinateSpace,
            mediaBox: mediaBox
        )

        context.saveGState()
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: pixelRect)
        context.setStrokeColor(UIColor.label.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: pixelRect)

        if isSelected {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(2)
            context.stroke(pixelRect.insetBy(dx: -2, dy: -2))
        }

        context.restoreGState()
    }
}

enum AnnotationPDFExporter {
    static func drawAnnotations(
        _ annotations: [PageAnnotation],
        in mediaBox: CGRect,
        pageRotation: Int,
        context: CGContext
    ) {
        let renderSize = mediaBox.size
        AnnotationRenderer.drawAnnotations(
            annotations,
            pageRotation: pageRotation,
            renderSize: renderSize,
            in: context,
            coordinateSpace: .pdfMediaBox,
            mediaBox: mediaBox
        )
    }
}

enum AnnotationCompositor {
    static func composite(
        baseImage: UIImage,
        annotations: [PageAnnotation],
        pageRotation: Int,
        selectedAnnotationID: UUID? = nil
    ) -> UIImage {
        guard !annotations.isEmpty else { return baseImage }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = baseImage.scale
        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)

        return renderer.image { rendererContext in
            baseImage.draw(at: .zero)
            let context = rendererContext.cgContext
            AnnotationRenderer.drawAnnotations(
                annotations,
                pageRotation: pageRotation,
                renderSize: baseImage.size,
                in: context,
                coordinateSpace: .topLeftOrigin,
                selectedAnnotationID: selectedAnnotationID
            )
        }
    }
}
