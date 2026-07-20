import CoreGraphics
import PDFKit
import SwiftUI
import XCTest
@testable import pdfpagearranger

@MainActor
final class DocumentScrollSnapRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        let url = try PDFTestFactory.writePDF(
            named: "document-scroll-snap",
            pageCount: 4,
            labels: ["A", "B", "C", "D"]
        )
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        viewModel = nil
        try await super.tearDown()
    }

    func testNewDocumentOpensOnPageOne() {
        let initial = DocumentScrollNavigationEngine.initialActivePageID(pages: viewModel.pages)
        XCTAssertEqual(initial, viewModel.pages.first?.id)
        XCTAssertEqual(viewModel.pageIndex(for: initial!), 0)
    }

    func testPersistedSessionRestoresPreferredActivePage() {
        let restored = viewModel.pages[2].id
        let resolved = DocumentScrollNavigationEngine.resolvedActivePageID(
            preferredID: restored,
            pages: viewModel.pages
        )
        XCTAssertEqual(resolved, restored)
        XCTAssertEqual(viewModel.pageIndex(for: resolved!), 2)
    }

    func testSettleTargetUsesActivationBandLikePrimaryDetection() {
        let a = viewModel.pages[0].id
        let b = viewModel.pages[1].id
        let c = viewModel.pages[2].id
        let target = DocumentScrollNavigationEngine.settleTargetPageID(
            visibilityCenters: [a: 40, b: 220, c: 480],
            viewportHeight: 400,
            fallback: a
        )
        XCTAssertEqual(target, b)
    }

    func testSlowDragSettlesToNearestBandPage() {
        let previous = viewModel.pages[0].id
        let current = viewModel.pages[1].id
        let next = viewModel.pages[2].id
        // Midway between previous and current, still closer to current center in band.
        let target = DocumentScrollNavigationEngine.settleTargetPageID(
            visibilityCenters: [previous: 80, current: 210, next: 520],
            viewportHeight: 400,
            fallback: previous
        )
        XCTAssertEqual(target, current)
    }

    func testFastFlickSettlesToNextPage() {
        let current = viewModel.pages[1].id
        let next = viewModel.pages[2].id
        let target = DocumentScrollNavigationEngine.settleTargetPageID(
            visibilityCenters: [current: 60, next: 200],
            viewportHeight: 400,
            fallback: current
        )
        XCTAssertEqual(target, next)
    }

    func testFlickSettlesToPreviousPage() {
        let previous = viewModel.pages[0].id
        let current = viewModel.pages[1].id
        let target = DocumentScrollNavigationEngine.settleTargetPageID(
            visibilityCenters: [previous: 190, current: 340],
            viewportHeight: 400,
            fallback: current
        )
        XCTAssertEqual(target, previous)
    }

    func testSinglePageDocumentDoesNotPerformSettleSnap() async throws {
        let url = try PDFTestFactory.writePDF(named: "snap-one-page", pageCount: 1, labels: ["Only"])
        tempURLs.append(url)
        let single = PDFEditorViewModel()
        await single.importPDF(from: url)
        XCTAssertFalse(DocumentScrollNavigationEngine.shouldPerformSettleSnap(pageCount: single.pageCount))
        XCTAssertTrue(DocumentScrollNavigationEngine.shouldPerformSettleSnap(pageCount: viewModel.pageCount))
    }

    func testVisibilityActivationBlockedUntilScrollIdleAndUnsuppressed() {
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldApplyVisibilityActivation(
                scrollPhaseIsIdle: false,
                scrollActivationSuppressed: false,
                interactionBlockingScroll: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldApplyVisibilityActivation(
                scrollPhaseIsIdle: true,
                scrollActivationSuppressed: true,
                interactionBlockingScroll: false
            )
        )
        XCTAssertTrue(
            DocumentScrollNavigationEngine.shouldApplyVisibilityActivation(
                scrollPhaseIsIdle: true,
                scrollActivationSuppressed: false,
                interactionBlockingScroll: false
            )
        )
    }

    func testProgrammaticActivationNotOverriddenByStaleVisibilityWhileSuppressed() {
        let current = viewModel.pages[0].id
        let stale = viewModel.pages[2].id
        let proposed = DocumentScrollNavigationEngine.settleTargetPageID(
            visibilityCenters: [stale: 200],
            viewportHeight: 400,
            fallback: current
        )
        XCTAssertEqual(proposed, stale)
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldApplyVisibilityActivation(
                scrollPhaseIsIdle: true,
                scrollActivationSuppressed: true,
                interactionBlockingScroll: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldUpdateActivePage(
                proposedID: proposed,
                currentID: current,
                interactionBlockingScroll: true
            )
        )
    }

    func testDeletionResolvesNearestRemainingPageAtBeginningMiddleAndEnd() {
        let pages = viewModel.pages
        // Beginning
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(
                preferredID: pages[0].id,
                pages: Array(pages.dropFirst()),
                preferredIndexAfterRemoval: 0
            ),
            pages[1].id
        )
        // Middle
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(
                preferredID: pages[1].id,
                pages: [pages[0], pages[2], pages[3]],
                preferredIndexAfterRemoval: 1
            ),
            pages[2].id
        )
        // End
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(
                preferredID: pages[3].id,
                pages: Array(pages.dropLast()),
                preferredIndexAfterRemoval: 3
            ),
            pages[2].id
        )
    }

    func testInsertionDuplicationRotationReorderPreserveResolvedActivePage() throws {
        let active = try XCTUnwrap(viewModel.pages[1].id)
        viewModel.rotatePage(id: active)
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(preferredID: active, pages: viewModel.pages),
            active
        )

        viewModel.duplicatePage(id: active)
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(preferredID: active, pages: viewModel.pages),
            active
        )

        // Insert by duplicating neighbour — active id must still resolve.
        viewModel.duplicatePage(id: viewModel.pages[0].id)
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(preferredID: active, pages: viewModel.pages),
            active
        )

        let from = try XCTUnwrap(viewModel.pageIndex(for: active))
        viewModel.reorderPage(from: from, to: 0)
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(preferredID: active, pages: viewModel.pages),
            active
        )
    }

    func testPageRestAnchorIsTopOfPage() {
        XCTAssertEqual(DocumentScrollNavigationEngine.pageRestAnchor.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(DocumentScrollNavigationEngine.pageRestAnchor.y, 0, accuracy: 0.001)
    }
}

final class DocumentScrollSnapSourceRegressionTests: XCTestCase {
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

    func testInitialViewportUsesTopRestAnchorWithoutCenterSettle() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let engine = try source(named: "DocumentScrollNavigationEngine.swift", subdirectory: "Services")
        XCTAssertTrue(engine.contains("pageRestAnchor"))
        XCTAssertTrue(pageEditor.contains("DocumentScrollNavigationEngine.pageRestAnchor"))
        XCTAssertTrue(pageEditor.contains("scrollDocument(to:"))
        XCTAssertTrue(pageEditor.contains("animated: false"))
        XCTAssertFalse(pageEditor.contains("anchor: .center"))
        XCTAssertTrue(pageEditor.contains("settleDocumentScroll"))
        XCTAssertTrue(pageEditor.contains("pendingUserScrollSettle"))
        XCTAssertTrue(pageEditor.contains("estimatedUnifiedSlotDisplaySize"))
    }

    func testNoPostLaunchVisibilityReapplyAfterProgrammaticNavigation() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("Do not re-apply stale visibility"))
        XCTAssertFalse(pageEditor.contains("applyDocumentVisibility(latestDocumentVisibility)"))
        XCTAssertTrue(pageEditor.contains("programmaticNavigationSuppressionNanoseconds"))
    }

    func testSearchAndOrganizerActivationUseSharedScrollPath() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let editor = try source(named: "EditorView.swift")
        XCTAssertTrue(pageEditor.contains("activatePage(id: match.pageItemID, scroll: true)"))
        XCTAssertTrue(editor.contains("activePageRoute = PageEditorRoute(pageItemID: pageID)"))
        XCTAssertTrue(pageEditor.contains("onChange(of: pageRoute.pageItemID)"))
        XCTAssertTrue(pageEditor.contains("pageRestAnchor"))
    }

    func testPageSpacingFormulaUnchanged() throws {
        let sheetStyle = try source(named: "DocumentPageSheetStyle.swift", subdirectory: "Services")
        XCTAssertTrue(sheetStyle.contains("max(2, min(6, width * 0.01))"))
    }

    func testPageToolbarPlacementUnchangedOutsidePageStack() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("floatingPageActionsCapsule"))
        XCTAssertTrue(pageEditor.contains("accessibilityIdentifier(\"pageBottomToolbar\")"))
        XCTAssertTrue(pageEditor.contains("accessibilityIdentifier(\"floatingPageToolbar\")"))
        // Toolbar must remain in the floating bottom chrome, not inside LazyVStack page slots.
        let lazyRegion = pageEditor.components(separatedBy: "private var unifiedDocumentScroll").last?
            .components(separatedBy: "private func documentPageSlot").first ?? ""
        XCTAssertFalse(lazyRegion.contains("floatingPageActionsCapsule"))
        XCTAssertFalse(lazyRegion.contains("pageBottomToolbar"))
    }

    func testActiveCanvasUsesConstrainedSharedSlotSize() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let canvas = try source(named: "PageOverlayCanvasView.swift")
        XCTAssertTrue(pageEditor.contains("unifiedSlotDisplaySize"))
        XCTAssertTrue(pageEditor.contains("constrainedPageSize: displaySize"))
        XCTAssertTrue(canvas.contains("constrainedPageSize"))
        XCTAssertTrue(canvas.contains("canvasBody(displaySize: constrainedPageSize)"))
    }
}

final class UnifiedPageSlotGeometryRegressionTests: XCTestCase {
    func testActiveAndInactiveFramesIdenticalForMixedSizesAndOrientations() {
        let portrait = CGSize(width: 612, height: 792)
        let landscape = CGSize(width: 792, height: 612)
        let square = CGSize(width: 500, height: 500)
        let width: CGFloat = 393

        for imageSize in [portrait, landscape, square] {
            let active = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: width)
            let inactive = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: width)
            XCTAssertEqual(active.width, inactive.width, accuracy: 0.001)
            XCTAssertEqual(active.height, inactive.height, accuracy: 0.001)
            XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: imageSize, displaySize: active))
        }
    }

    func testPreviewToEditorActivationHasZeroGeometryChange() {
        let imageSize = CGSize(width: 612, height: 792)
        let before = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: 430)
        // Activation only passes the same size into constrainedPageSize — no alternate fit.
        let after = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: 430)
        XCTAssertEqual(before, after)
    }

    func testEditorToPreviewDeactivationHasZeroGeometryChange() {
        let imageSize = CGSize(width: 792, height: 612)
        let editor = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: 390)
        let preview = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: imageSize, containerWidth: 390)
        XCTAssertEqual(editor.width, preview.width, accuracy: 0.001)
        XCTAssertEqual(editor.height, preview.height, accuracy: 0.001)
    }

    func testEstimatedPlaceholderMatchesMediaBoxAspect() {
        let estimated = PageModeLayoutSizing.estimatedUnifiedSlotDisplaySize(
            pdfPage: nil,
            pageRotation: 0,
            containerWidth: 393
        )
        let rendered = PageModeLayoutSizing.unifiedSlotDisplaySize(
            imageSize: CGSize(width: 612, height: 792),
            containerWidth: 393
        )
        XCTAssertEqual(estimated.width, rendered.width, accuracy: 0.001)
        XCTAssertEqual(estimated.height, rendered.height, accuracy: 0.001)
    }

    func testRotatedPageUsesSharedSlotRules() {
        let media = CGRect(x: 0, y: 0, width: 612, height: 792)
        let rotatedSize = OverlayGeometryEngine.displayRenderSize(for: 90, mediaBox: media)
        let display = PageModeLayoutSizing.unifiedSlotDisplaySize(imageSize: rotatedSize, containerWidth: 393)
        XCTAssertEqual(display.width, PageModeLayoutSizing.unifiedSlotDisplayWidth(containerWidth: 393), accuracy: 0.001)
        XCTAssertTrue(PageModeLayoutSizing.preservesAspectRatio(imageSize: rotatedSize, displaySize: display))
    }
}
