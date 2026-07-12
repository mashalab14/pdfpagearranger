import SwiftUI

struct HighlightContextMenu: View {
    let anchorPoint: CGPoint
    let onColor: (HighlightPresetColor) -> Void
    let onDelete: () -> Void
    let onComment: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(HighlightPresetColor.allCases, id: \.self) { color in
                    Button {
                        onColor(color)
                    } label: {
                        Circle()
                            .fill(Color(color.rgba.uiColor))
                            .frame(width: 22, height: 22)
                            .overlay {
                                Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(color.rawValue.capitalized) highlight")
                    .accessibilityIdentifier("highlightColor_\(color.rawValue)")
                }
            }

            HStack(spacing: ContextualControlMetrics.toolbarCellSpacing) {
                toolbarButton(systemName: "bubble.left", label: "Comment", id: "highlightMenuComment", action: onComment)
                divider
                toolbarButton(systemName: "trash", label: "Delete", id: "highlightMenuDelete", action: onDelete, isDestructive: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contextualGlassContainer()
        .fixedSize(horizontal: true, vertical: true)
        .position(anchorPoint)
        .accessibilityIdentifier("highlightContextMenu")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(ContextualControlMetrics.toolbarDividerOpacity))
            .frame(width: 1, height: ContextualControlMetrics.toolbarDividerHeight)
    }

    private func toolbarButton(
        systemName: String,
        label: String,
        id: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(ContextualControlMetrics.toolbarSymbolFont)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct StickyNoteContextMenu: View {
    let anchorPoint: CGPoint
    let noteText: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(noteText)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .frame(maxWidth: 220, alignment: .leading)

            HStack(spacing: ContextualControlMetrics.toolbarCellSpacing) {
                toolbarButton(systemName: "pencil", label: "Edit", id: "stickyNoteMenuEdit", action: onEdit)
                divider
                toolbarButton(systemName: "trash", label: "Delete", id: "stickyNoteMenuDelete", action: onDelete, isDestructive: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contextualGlassContainer()
        .fixedSize(horizontal: true, vertical: true)
        .position(anchorPoint)
        .accessibilityIdentifier("stickyNoteContextMenu")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(ContextualControlMetrics.toolbarDividerOpacity))
            .frame(width: 1, height: ContextualControlMetrics.toolbarDividerHeight)
    }

    private func toolbarButton(
        systemName: String,
        label: String,
        id: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(ContextualControlMetrics.toolbarSymbolFont)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct TextCommentPopover: View {
    let anchorPoint: CGPoint
    let selectedText: String
    let commentText: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(commentText)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(4)

            HStack(spacing: ContextualControlMetrics.toolbarCellSpacing) {
                toolbarButton(systemName: "pencil", label: "Edit", id: "textCommentMenuEdit", action: onEdit)
                divider
                toolbarButton(systemName: "trash", label: "Delete", id: "textCommentMenuDelete", action: onDelete, isDestructive: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contextualGlassContainer()
        .fixedSize(horizontal: true, vertical: true)
        .position(anchorPoint)
        .accessibilityIdentifier("textCommentPopover")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(ContextualControlMetrics.toolbarDividerOpacity))
            .frame(width: 1, height: ContextualControlMetrics.toolbarDividerHeight)
    }

    private func toolbarButton(
        systemName: String,
        label: String,
        id: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(ContextualControlMetrics.toolbarSymbolFont)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct DrawingContextMenu: View {
    let anchorPoint: CGPoint
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: ContextualControlMetrics.toolbarCellSpacing) {
            toolbarButton(systemName: "trash", label: "Delete Drawing", id: "drawingMenuDelete", action: onDelete, isDestructive: true)
        }
        .frame(height: ContextualControlMetrics.toolbarVisibleHeight)
        .contextualGlassContainer()
        .fixedSize(horizontal: true, vertical: true)
        .position(anchorPoint)
        .accessibilityIdentifier("drawingContextMenu")
    }

    private func toolbarButton(
        systemName: String,
        label: String,
        id: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(ContextualControlMetrics.toolbarSymbolFont)
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

enum AnnotationMenuEngine {
    static func stickyNoteMarkerCenter(
        storagePosition: PageNormalizedPoint,
        pageRotation: Int,
        pageSize: CGSize
    ) -> CGPoint {
        let displayPosition = AnnotationGeometryEngine.displayPoint(from: storagePosition, pageRotation: pageRotation)
        return AnnotationGeometryEngine.pixelPoint(
            normalizedPoint: displayPosition,
            renderSize: pageSize,
            coordinateSpace: .topLeftOrigin
        )
    }

    static func anchorPoint(for annotation: PageAnnotation, pageRotation: Int, pageSize: CGSize) -> CGPoint {
        switch annotation.kind {
        case .highlight, .textComment:
            let rects = AnnotationGeometryEngine.displayRects(
                from: annotation.normalizedRects ?? [],
                pageRotation: pageRotation
            )
            guard let union = AnnotationGeometryEngine.unionAnchorRect(for: rects) else {
                return CGPoint(x: pageSize.width / 2, y: 24)
            }
            let pixelRect = AnnotationGeometryEngine.pixelRect(
                normalizedRect: union,
                renderSize: pageSize,
                coordinateSpace: .topLeftOrigin
            )
            return CGPoint(x: pixelRect.midX, y: max(pixelRect.minY - 28, 24))
        case .stickyNote:
            guard let position = annotation.normalizedPosition else {
                return CGPoint(x: pageSize.width / 2, y: pageSize.height / 2)
            }
            let pixelPoint = stickyNoteMarkerCenter(
                storagePosition: position,
                pageRotation: pageRotation,
                pageSize: pageSize
            )
            return CGPoint(x: pixelPoint.x, y: max(pixelPoint.y - 36, 24))
        case .drawing:
            if let bounds = AnnotationRenderer.drawingBounds(for: annotation, pageRotation: pageRotation) {
                let pixelRect = AnnotationGeometryEngine.pixelRect(
                    normalizedRect: bounds,
                    renderSize: pageSize,
                    coordinateSpace: .topLeftOrigin
                )
                return CGPoint(x: pixelRect.midX, y: max(pixelRect.minY - 28, 24))
            }
            return CGPoint(x: pageSize.width / 2, y: 24)
        }
    }
}
