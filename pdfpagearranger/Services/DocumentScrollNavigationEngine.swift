import CoreGraphics
import Foundation
import SwiftUI

/// Navigation helpers for the unified vertically scrolling document surface.
enum DocumentScrollNavigationEngine {
    /// Fraction of the viewport a page's frame must cover (by mid-Y proximity) to become active while settling.
    static let activationMidYNormalizedRange: ClosedRange<CGFloat> = 0.28...0.72

    /// Resting scroll position: top of the active page aligned to the top of the viewport.
    /// Used for open, snap-after-scroll, search, Pages organizer, and programmatic activation.
    static let pageRestAnchor = UnitPoint(x: 0.5, y: 0)

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

    /// Page that should become active when a drag/deceleration ends.
    static func settleTargetPageID(
        visibilityCenters: [UUID: CGFloat],
        viewportHeight: CGFloat,
        fallback: UUID?
    ) -> UUID? {
        primaryPageID(
            visibilityCenters: visibilityCenters,
            viewportHeight: viewportHeight,
            fallback: fallback
        )
    }

    /// Multi-page documents snap after scrolling ends; single-page documents stay put.
    static func shouldPerformSettleSnap(pageCount: Int) -> Bool {
        pageCount > 1
    }

    /// Visibility-driven activation is deferred until scroll settles; programmatic navigation suppresses it.
    static func shouldApplyVisibilityActivation(
        scrollPhaseIsIdle: Bool,
        scrollActivationSuppressed: Bool,
        interactionBlockingScroll: Bool
    ) -> Bool {
        scrollPhaseIsIdle
            && !scrollActivationSuppressed
            && !interactionBlockingScroll
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

    /// Default active page for a newly opened document (page 1).
    static func initialActivePageID(pages: [PageItem]) -> UUID? {
        pages.first?.id
    }

    static func pageSpacing(forContainerWidth width: CGFloat) -> CGFloat {
        DocumentPageSheetStyle.pageSpacing(forContainerWidth: width)
    }

    /// Delay before floating chrome fades back in after scroll settles.
    static let floatingChromeRevealDelayNanoseconds: UInt64 = 280_000_000

    /// Suppression window so lazy layout / preview→canvas swaps cannot override programmatic navigation.
    static let programmaticNavigationSuppressionNanoseconds: UInt64 = 900_000_000
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

/// Live content offset of the unified document stack inside `documentScroll` space.
struct DocumentScrollContentOffsetKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}
