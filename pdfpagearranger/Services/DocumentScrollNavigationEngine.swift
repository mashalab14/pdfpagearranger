import CoreGraphics
import Foundation
import SwiftUI

/// Navigation helpers for the unified vertically scrolling document surface.
enum DocumentScrollNavigationEngine {
    /// Fraction of the viewport a page's frame must cover (by mid-Y proximity) to become active while scrolling.
    static let activationMidYNormalizedRange: ClosedRange<CGFloat> = 0.28...0.72

    /// Chooses the page whose vertical center is closest to the viewport center.
    /// Prefers pages whose mid-Y falls in `activationMidYNormalizedRange`; if none qualify, falls back to the closest overall.
    static func primaryPageID(
        visibilityCenters: [UUID: CGFloat],
        viewportHeight: CGFloat,
        fallback: UUID?
    ) -> UUID? {
        guard viewportHeight > 0, !visibilityCenters.isEmpty else { return fallback }
        let viewportCenter = viewportHeight / 2
        let inActivationBand = visibilityCenters.filter { _, midY in
            activationMidYNormalizedRange.contains(midY / viewportHeight)
        }
        let candidates = inActivationBand.isEmpty ? visibilityCenters : inActivationBand
        let ranked = candidates.min { lhs, rhs in
            abs(lhs.value - viewportCenter) < abs(rhs.value - viewportCenter)
        }
        return ranked?.key ?? fallback
    }

    static func shouldUpdateActivePage(
        proposedID: UUID?,
        currentID: UUID,
        interactionBlockingScroll: Bool
    ) -> Bool {
        guard !interactionBlockingScroll,
              let proposedID,
              proposedID != currentID else {
            return false
        }
        return true
    }

    static func resolvedActivePageID(
        preferredID: UUID?,
        pages: [PageItem],
        preferredIndexAfterRemoval: Int? = nil
    ) -> UUID? {
        guard !pages.isEmpty else { return nil }
        if let preferredID, pages.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        if let preferredIndexAfterRemoval {
            let index = min(max(preferredIndexAfterRemoval, 0), pages.count - 1)
            return pages[index].id
        }
        return pages.first?.id
    }

    static func pageSpacing(forContainerWidth width: CGFloat) -> CGFloat {
        max(16, min(28, width * 0.04))
    }
}

/// Preference payload for scroll-based active-page detection.
struct DocumentPageVisibility: Equatable {
    var centersInViewport: [UUID: CGFloat] = [:]
    var viewportHeight: CGFloat = 0
}

struct DocumentPageVisibilityKey: PreferenceKey {
    static var defaultValue = DocumentPageVisibility()

    static func reduce(value: inout DocumentPageVisibility, nextValue: () -> DocumentPageVisibility) {
        let next = nextValue()
        value.centersInViewport.merge(next.centersInViewport, uniquingKeysWith: { _, new in new })
        if next.viewportHeight > 0 {
            value.viewportHeight = next.viewportHeight
        }
    }
}
