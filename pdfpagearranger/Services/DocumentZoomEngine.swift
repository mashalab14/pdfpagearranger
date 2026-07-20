import CoreGraphics
import Foundation
import SwiftUI

/// Shared magnification for the unified vertical document surface.
struct DocumentZoomState: Equatable {
    static let minScale: CGFloat = 1
    static let maxScale: CGFloat = 4
    /// Tolerance around fitted-width zoom (avoid exact float equality).
    static let fittedWidthTolerance: CGFloat = 0.01

    /// Current document magnification. `1` is fitted-width layout.
    var scale: CGFloat = minScale
    /// Scale at the start of the current pinch.
    var steadyScale: CGFloat = minScale

    var isMagnified: Bool {
        DocumentZoomEngine.isMagnified(scale)
    }

    mutating func applyMagnification(_ magnification: CGFloat) {
        scale = DocumentZoomEngine.clampedScale(steadyScale * magnification)
    }

    mutating func endMagnification() {
        steadyScale = scale
        if !isMagnified {
            resetToFittedWidth()
        }
    }

    mutating func resetToFittedWidth() {
        scale = Self.minScale
        steadyScale = Self.minScale
    }
}

/// Pure helpers for document-owned zoom layout and focal-point scroll adjustment.
enum DocumentZoomEngine {
    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, DocumentZoomState.minScale), DocumentZoomState.maxScale)
    }

    static func isMagnified(_ scale: CGFloat) -> Bool {
        scale > DocumentZoomState.minScale + DocumentZoomState.fittedWidthTolerance
    }

    static func isAtFittedWidth(_ scale: CGFloat) -> Bool {
        !isMagnified(scale)
    }

    /// Scales a fitted-width page frame so layout (not a post-layout transform) owns magnification.
    static func scaledPageSize(fittedSize: CGSize, scale: CGFloat) -> CGSize {
        let clamped = clampedScale(scale)
        return CGSize(width: fittedSize.width * clamped, height: fittedSize.height * clamped)
    }

    /// Page gap scales with document zoom so enlarged pages never overlap.
    static func scaledPageSpacing(fittedSpacing: CGFloat, scale: CGFloat) -> CGFloat {
        fittedSpacing * clampedScale(scale)
    }

    /// Content width of the scrollable stack at the current zoom (pages + horizontal margins).
    static func scaledContentWidth(
        containerWidth: CGFloat,
        horizontalMargin: CGFloat,
        scale: CGFloat
    ) -> CGFloat {
        let fittedPageWidth = max(0, containerWidth - horizontalMargin * 2)
        return fittedPageWidth * clampedScale(scale) + horizontalMargin * 2
    }

    /// Keeps the document point under the pinch centroid stable when scale changes.
    /// Assumes content layout scales uniformly from the top-leading content origin.
    static func contentOffsetPreservingFocalPoint(
        previousScale: CGFloat,
        newScale: CGFloat,
        focalPointInViewport: CGPoint,
        contentOffset: CGPoint
    ) -> CGPoint {
        let from = max(previousScale, 0.01)
        let to = clampedScale(newScale)
        let ratio = to / from
        let contentX = contentOffset.x + focalPointInViewport.x
        let contentY = contentOffset.y + focalPointInViewport.y
        return CGPoint(
            x: max(0, contentX * ratio - focalPointInViewport.x),
            y: max(0, contentY * ratio - focalPointInViewport.y)
        )
    }

    /// Unit-point anchor so the page region under the pinch stays in the viewport while layout rescales.
    static func pageScrollAnchor(
        focalPointInViewport: CGPoint,
        viewportSize: CGSize
    ) -> UnitPoint {
        let x = viewportSize.width > 0 ? focalPointInViewport.x / viewportSize.width : 0.5
        let y = viewportSize.height > 0 ? focalPointInViewport.y / viewportSize.height : 0.3
        return UnitPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }

    /// True when a reported scroll offset is too near the origin to trust for mid-document zoom.
    static func isUntrustedContentOffset(_ offset: CGPoint, pageIndex: Int) -> Bool {
        pageIndex > 0 && offset.y < 1
    }

    /// Settle / active-page updates must not run while pinch is preserving scroll position.
    static func shouldFreezeNavigationDuringZoom(
        isPinching: Bool,
        positionRestoreSuppressed: Bool
    ) -> Bool {
        isPinching || positionRestoreSuppressed
    }
}
