import CoreGraphics
import SwiftUI
import XCTest
@testable import pdfpagearranger

final class DocumentZoomEngineRegressionTests: XCTestCase {
    func testClampedScaleEnforcesMinAndMax() {
        XCTAssertEqual(DocumentZoomEngine.clampedScale(0.5), 1, accuracy: 0.001)
        XCTAssertEqual(DocumentZoomEngine.clampedScale(1), 1, accuracy: 0.001)
        XCTAssertEqual(DocumentZoomEngine.clampedScale(2.5), 2.5, accuracy: 0.001)
        XCTAssertEqual(DocumentZoomEngine.clampedScale(10), 4, accuracy: 0.001)
    }

    func testFittedWidthTolerance() {
        XCTAssertFalse(DocumentZoomEngine.isMagnified(1))
        XCTAssertFalse(DocumentZoomEngine.isMagnified(1.005))
        XCTAssertTrue(DocumentZoomEngine.isMagnified(1.02))
        XCTAssertTrue(DocumentZoomEngine.isAtFittedWidth(1))
        XCTAssertFalse(DocumentZoomEngine.isAtFittedWidth(2))
    }

    func testScaledPageSizeKeepsAspectAndSharesScale() {
        let fitted = CGSize(width: 300, height: 400)
        let active = DocumentZoomEngine.scaledPageSize(fittedSize: fitted, scale: 2)
        let inactive = DocumentZoomEngine.scaledPageSize(fittedSize: fitted, scale: 2)
        XCTAssertEqual(active.width, inactive.width, accuracy: 0.001)
        XCTAssertEqual(active.height, inactive.height, accuracy: 0.001)
        XCTAssertEqual(active.width, 600, accuracy: 0.001)
        XCTAssertEqual(active.height, 800, accuracy: 0.001)
    }

    func testScaledSpacingPreventsOverlapByGrowingGaps() {
        let fittedSpacing: CGFloat = 4
        XCTAssertEqual(DocumentZoomEngine.scaledPageSpacing(fittedSpacing: fittedSpacing, scale: 1), 4, accuracy: 0.001)
        XCTAssertEqual(DocumentZoomEngine.scaledPageSpacing(fittedSpacing: fittedSpacing, scale: 2), 8, accuracy: 0.001)
        XCTAssertGreaterThan(
            DocumentZoomEngine.scaledPageSpacing(fittedSpacing: fittedSpacing, scale: 2),
            fittedSpacing
        )
    }

    func testScaledContentWidthIncludesEveryPageSlotAtZoom() {
        let width = DocumentZoomEngine.scaledContentWidth(
            containerWidth: 393,
            horizontalMargin: 12,
            scale: 2
        )
        // fitted page width 369 * 2 + 24 margins
        XCTAssertEqual(width, 369 * 2 + 24, accuracy: 0.001)
        let fitted = DocumentZoomEngine.scaledContentWidth(
            containerWidth: 393,
            horizontalMargin: 12,
            scale: 1
        )
        XCTAssertEqual(fitted, 393, accuracy: 0.001)
    }

    func testPinchFocalPointOffsetStaysStable() {
        let startOffset = CGPoint(x: 40, y: 120)
        let focal = CGPoint(x: 100, y: 200)
        let newOffset = DocumentZoomEngine.contentOffsetPreservingFocalPoint(
            previousScale: 1,
            newScale: 2,
            focalPointInViewport: focal,
            contentOffset: startOffset
        )
        // Content point (140, 320) scales to (280, 640); offset = that - focal.
        XCTAssertEqual(newOffset.x, 180, accuracy: 0.001)
        XCTAssertEqual(newOffset.y, 440, accuracy: 0.001)

        let restored = DocumentZoomEngine.contentOffsetPreservingFocalPoint(
            previousScale: 2,
            newScale: 1,
            focalPointInViewport: focal,
            contentOffset: newOffset
        )
        XCTAssertEqual(restored.x, startOffset.x, accuracy: 0.001)
        XCTAssertEqual(restored.y, startOffset.y, accuracy: 0.001)
    }

    func testMinimumZoomRestoresFittedGeometry() {
        var zoom = DocumentZoomState()
        zoom.scale = 3
        zoom.steadyScale = 3
        zoom.resetToFittedWidth()
        XCTAssertEqual(zoom.scale, 1, accuracy: 0.001)
        XCTAssertFalse(zoom.isMagnified)

        let fitted = CGSize(width: 361, height: 500)
        let restored = DocumentZoomEngine.scaledPageSize(fittedSize: fitted, scale: zoom.scale)
        XCTAssertEqual(restored, fitted)
    }

    func testMaximumZoomIsEnforcedOnApply() {
        var zoom = DocumentZoomState()
        zoom.steadyScale = 1
        zoom.applyMagnification(10)
        XCTAssertEqual(zoom.scale, DocumentZoomState.maxScale, accuracy: 0.001)
    }

    func testMixedOrientationsShareOneZoomScale() {
        let portrait = CGSize(width: 300, height: 400)
        let landscape = CGSize(width: 400, height: 300)
        let scale: CGFloat = 1.75
        let p = DocumentZoomEngine.scaledPageSize(fittedSize: portrait, scale: scale)
        let l = DocumentZoomEngine.scaledPageSize(fittedSize: landscape, scale: scale)
        XCTAssertEqual(p.width / portrait.width, l.width / landscape.width, accuracy: 0.001)
        XCTAssertEqual(p.height / portrait.height, l.height / landscape.height, accuracy: 0.001)
    }

    func testExportGeometryIndependentOfDisplayZoom() {
        // Normalized overlay centers are display-zoom agnostic.
        let normalized = CGPoint(x: 0.4, y: 0.6)
        let fittedPage = CGSize(width: 300, height: 400)
        let atFit = OverlayInteractionEngine.clampNormalizedPoint(normalized)
        let atZoomDisplay = DocumentZoomEngine.scaledPageSize(fittedSize: fittedPage, scale: 2.5)
        // Mapping normalized → display uses current display size; storage stays normalized.
        XCTAssertEqual(atFit.x, normalized.x, accuracy: 0.001)
        XCTAssertEqual(atZoomDisplay.width / fittedPage.width, 2.5, accuracy: 0.001)
        XCTAssertEqual(DocumentZoomEngine.clampedScale(2.5), 2.5, accuracy: 0.001)
    }

    func testUntrustedOriginOffsetDetectedForMidDocumentPages() {
        XCTAssertTrue(
            DocumentZoomEngine.isUntrustedContentOffset(.zero, pageIndex: 4)
        )
        XCTAssertFalse(
            DocumentZoomEngine.isUntrustedContentOffset(CGPoint(x: 0, y: 1200), pageIndex: 4)
        )
        XCTAssertFalse(
            DocumentZoomEngine.isUntrustedContentOffset(.zero, pageIndex: 0)
        )
    }

    func testNavigationFrozenDuringPinchAndPositionRestore() {
        XCTAssertTrue(
            DocumentZoomEngine.shouldFreezeNavigationDuringZoom(
                isPinching: true,
                positionRestoreSuppressed: false
            )
        )
        XCTAssertTrue(
            DocumentZoomEngine.shouldFreezeNavigationDuringZoom(
                isPinching: false,
                positionRestoreSuppressed: true
            )
        )
        XCTAssertFalse(
            DocumentZoomEngine.shouldFreezeNavigationDuringZoom(
                isPinching: false,
                positionRestoreSuppressed: false
            )
        )
    }

    func testPageScrollAnchorMapsFocalPointIntoUnitSquare() {
        let anchor = DocumentZoomEngine.pageScrollAnchor(
            focalPointInViewport: CGPoint(x: 100, y: 200),
            viewportSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(anchor.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(anchor.y, 0.25, accuracy: 0.001)
    }

    func testFocalPointOffsetFromMidDocumentDoesNotCollapseToOrigin() {
        let start = CGPoint(x: 20, y: 2400) // page ~5 territory
        let focal = CGPoint(x: 180, y: 320)
        let zoomed = DocumentZoomEngine.contentOffsetPreservingFocalPoint(
            previousScale: 1,
            newScale: 2,
            focalPointInViewport: focal,
            contentOffset: start
        )
        XCTAssertGreaterThan(zoomed.y, 2000)
        XCTAssertNotEqual(zoomed.y, 0, accuracy: 0.001)
    }
}

final class DocumentZoomSourceRegressionTests: XCTestCase {
    private func source(named fileName: String, subdirectory: String = "Views") throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot
                .appendingPathComponent("pdfpagearranger")
                .appendingPathComponent(subdirectory)
                .appendingPathComponent(fileName),
            encoding: .utf8
        )
    }

    func testDocumentOwnsSharedZoomState() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let canvas = try source(named: "PageOverlayCanvasView.swift")
        XCTAssertTrue(pageEditor.contains("documentZoom"))
        XCTAssertTrue(pageEditor.contains("DocumentZoomState"))
        XCTAssertTrue(pageEditor.contains("documentMagnifyGesture"))
        XCTAssertTrue(pageEditor.contains("MagnifyGesture()"))
        XCTAssertTrue(pageEditor.contains("pageLocalZoomEnabled: false"))
        XCTAssertTrue(canvas.contains("pageLocalZoomEnabled"))
        XCTAssertTrue(canvas.contains("effectiveCanvasScale"))
    }

    func testPinchOnAnyPageUsesDocumentScale() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("scaledPageSize(fittedSize:"))
        XCTAssertTrue(pageEditor.contains("scaledPageSpacing(fittedSpacing:"))
        XCTAssertTrue(pageEditor.contains("zoomScale: zoomScale"))
        XCTAssertTrue(pageEditor.contains("contentOffsetPreservingFocalPoint"))
    }

    func testZoomPreservesAnchoredPageInsteadOfDocumentOrigin() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let engine = try source(named: "DocumentZoomEngine.swift", subdirectory: "Services")
        XCTAssertTrue(pageEditor.contains("pinchAnchoredPageID"))
        XCTAssertTrue(pageEditor.contains("trackedDocumentContentOffset"))
        XCTAssertTrue(pageEditor.contains("DocumentScrollContentOffsetKey"))
        XCTAssertTrue(pageEditor.contains("restoreZoomAnchoredScroll"))
        XCTAssertTrue(pageEditor.contains("zoomPositionRestoreSuppressed"))
        XCTAssertTrue(pageEditor.contains("shouldFreezeNavigationDuringZoom"))
        // Must not use ScrollPosition.point ?? .zero as the sole pinch origin (that resets to page 1).
        XCTAssertFalse(pageEditor.contains("documentScrollPosition.point ?? .zero"))
        XCTAssertTrue(engine.contains("isUntrustedContentOffset"))
        XCTAssertTrue(pageEditor.contains("scrollTo(anchoredPageID, anchor: pinchViewportAnchor)"))
    }

    func testFittedWidthResetKeepsCurrentPage() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("onDocumentZoomReset"))
        XCTAssertTrue(pageEditor.contains("documentZoom.resetToFittedWidth()"))
        XCTAssertTrue(pageEditor.contains("scrollTo(id: pageID, anchor: DocumentScrollNavigationEngine.pageRestAnchor)"))
    }

    func testActivePageSwitchDoesNotResetZoom() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        // Reset only via double-tap / explicit reset path — not when the active page changes.
        let activateRegion = pageEditor.components(separatedBy: "private func activatePage").last?
            .components(separatedBy: "private func beginScrollActivationSuppression").first ?? ""
        XCTAssertFalse(activateRegion.contains("documentZoom.reset"))
        XCTAssertFalse(activateRegion.contains("resetToFittedWidth"))
        XCTAssertTrue(pageEditor.contains("onDocumentZoomReset"))
        XCTAssertTrue(pageEditor.contains("documentZoom.resetToFittedWidth()"))
    }

    func testActivePageTrackingIndependentOfZoom() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let engine = try source(named: "DocumentZoomEngine.swift", subdirectory: "Services")
        XCTAssertTrue(pageEditor.contains("updateActivePageFromVisibility"))
        XCTAssertTrue(pageEditor.contains("activatePage(id: target, scroll: false)"))
        XCTAssertFalse(engine.contains("shouldPerformSettleSnap"))
        XCTAssertFalse(pageEditor.contains("DocumentZoomEngine.shouldPerformSettleSnap"))
        XCTAssertFalse(pageEditor.contains("settleDocumentScroll"))
    }

    func testHorizontalAndVerticalScrollWhileMagnified() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("ScrollView([.horizontal, .vertical])"))
        XCTAssertTrue(pageEditor.contains("scrollPosition($documentScrollPosition)"))
    }

    func testSearchAndOrganizerNavigationKeepZoomPath() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("activatePage(id: match.pageItemID, scroll: true)"))
        XCTAssertTrue(pageEditor.contains("scrollDocument(to:"))
        // Zoom state is not cleared in activatePage.
        let activateRegion = pageEditor.components(separatedBy: "private func activatePage").last?
            .components(separatedBy: "private func beginScrollActivationSuppression").first ?? ""
        XCTAssertFalse(activateRegion.contains("documentZoom.reset"))
        XCTAssertFalse(activateRegion.contains("documentZoom.scale"))
    }

    func testFittedWidthSpacingAndToolbarUnchanged() throws {
        let sheetStyle = try source(named: "DocumentPageSheetStyle.swift", subdirectory: "Services")
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(sheetStyle.contains("max(2, min(6, width * 0.01))"))
        XCTAssertTrue(pageEditor.contains("floatingPageActionsCapsule"))
        XCTAssertTrue(pageEditor.contains("accessibilityIdentifier(\"pageBottomToolbar\")"))
        let lazyRegion = pageEditor.components(separatedBy: "private var unifiedDocumentScroll").last?
            .components(separatedBy: "private func documentPageSlot").first ?? ""
        XCTAssertFalse(lazyRegion.contains("floatingPageActionsCapsule"))
    }

    func testPageLocalScaleEffectDisabledOnUnifiedCanvas() throws {
        let canvas = try source(named: "PageOverlayCanvasView.swift")
        XCTAssertTrue(canvas.contains(".scaleEffect(pageLocalZoomEnabled ? scale : 1)"))
        XCTAssertTrue(canvas.contains("pageLocalZoomEnabled"))
        XCTAssertTrue(canvas.contains("effectiveCanvasScale"))
    }

    func testOverlayHitTestingUsesDisplaySizeNotDocumentZoomState() throws {
        let canvas = try source(named: "PageOverlayCanvasView.swift")
        // Overlays receive the (already layout-scaled) pageSize; canvasScale is 1 when document owns zoom.
        XCTAssertTrue(canvas.contains("effectiveCanvasScale"))
        XCTAssertTrue(canvas.contains("pageSize: fitSize"))
    }
}
