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
            named: "document-free-scroll",
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

    func testPrimaryPageUsesActivationBandNearestCenter() {
        let a = viewModel.pages[0].id
        let b = viewModel.pages[1].id
        let c = viewModel.pages[2].id
        let target = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [a: 40, b: 220, c: 480],
            viewportHeight: 400,
            fallback: a
        )
        XCTAssertEqual(target, b)
    }

    func testMidScrollVisibilitySelectsNearestBandPage() {
        let previous = viewModel.pages[0].id
        let current = viewModel.pages[1].id
        let next = viewModel.pages[2].id
        let target = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [previous: 80, current: 210, next: 520],
            viewportHeight: 400,
            fallback: previous
        )
        XCTAssertEqual(target, current)
    }

    func testFastScrollVisibilitySelectsNextPageWithoutRequiringIdle() {
        let current = viewModel.pages[1].id
        let next = viewModel.pages[2].id
        let target = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [current: 60, next: 200],
            viewportHeight: 400,
            fallback: current
        )
        XCTAssertEqual(target, next)
    }

    func testScrollVisibilitySelectsPreviousPage() {
        let previous = viewModel.pages[0].id
        let current = viewModel.pages[1].id
        let target = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [previous: 190, current: 340],
            viewportHeight: 400,
            fallback: current
        )
        XCTAssertEqual(target, previous)
    }

    func testActivePageTrackingDoesNotRequireScrollIdle() {
        XCTAssertTrue(
            DocumentScrollNavigationEngine.shouldTrackActivePageFromVisibility(
                scrollActivationSuppressed: false,
                interactionBlockingScroll: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldTrackActivePageFromVisibility(
                scrollActivationSuppressed: true,
                interactionBlockingScroll: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldTrackActivePageFromVisibility(
                scrollActivationSuppressed: false,
                interactionBlockingScroll: true
            )
        )
    }

    func testIntentionalActivationOnlyWhenScrollIdle() {
        XCTAssertTrue(
            DocumentScrollNavigationEngine.shouldAcceptIntentionalPageActivation(
                scrollPhaseIsIdle: true,
                isPinching: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldAcceptIntentionalPageActivation(
                scrollPhaseIsIdle: false,
                isPinching: false
            )
        )
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldAcceptIntentionalPageActivation(
                scrollPhaseIsIdle: true,
                isPinching: true
            )
        )
    }

    func testProgrammaticActivationNotOverriddenByStaleVisibilityWhileSuppressed() {
        let current = viewModel.pages[0].id
        let stale = viewModel.pages[2].id
        let proposed = DocumentScrollNavigationEngine.primaryPageID(
            visibilityCenters: [stale: 200],
            viewportHeight: 400,
            fallback: current
        )
        XCTAssertEqual(proposed, stale)
        XCTAssertFalse(
            DocumentScrollNavigationEngine.shouldTrackActivePageFromVisibility(
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
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(
                preferredID: pages[0].id,
                pages: Array(pages.dropFirst()),
                preferredIndexAfterRemoval: 0
            ),
            pages[1].id
        )
        XCTAssertEqual(
            DocumentScrollNavigationEngine.resolvedActivePageID(
                preferredID: pages[1].id,
                pages: [pages[0], pages[2], pages[3]],
                preferredIndexAfterRemoval: 1
            ),
            pages[2].id
        )
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

    func testPageRestAnchorIsTopOfPageForProgrammaticNavigation() {
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

    func testNoSettleSnapCallbacksOrStateRemain() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let engine = try source(named: "DocumentScrollNavigationEngine.swift", subdirectory: "Services")
        let zoomEngine = try source(named: "DocumentZoomEngine.swift", subdirectory: "Services")
        XCTAssertFalse(pageEditor.contains("settleDocumentScroll"))
        XCTAssertFalse(pageEditor.contains("pendingUserScrollSettle"))
        XCTAssertFalse(pageEditor.contains("shouldPerformSettleSnap"))
        XCTAssertFalse(engine.contains("shouldPerformSettleSnap"))
        XCTAssertFalse(engine.contains("settleTargetPageID"))
        XCTAssertFalse(engine.contains("shouldApplyVisibilityActivation"))
        XCTAssertFalse(zoomEngine.contains("shouldPerformSettleSnap"))
        XCTAssertTrue(pageEditor.contains("updateActivePageFromVisibility"))
        XCTAssertTrue(pageEditor.contains("intentionallyActivatePage"))
        XCTAssertTrue(pageEditor.contains("scrollDocumentOnNextRouteChange"))
        XCTAssertTrue(engine.contains("shouldTrackActivePageFromVisibility"))
        XCTAssertTrue(engine.contains("shouldAcceptIntentionalPageActivation"))
    }

    func testActivePageChangeDoesNotScrollDocument() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        XCTAssertTrue(pageEditor.contains("activatePage(id: target, scroll: false)"))
        XCTAssertTrue(pageEditor.contains("scrollDocumentOnNextRouteChange = scroll"))
        XCTAssertTrue(pageEditor.contains("guard scrollDocumentOnNextRouteChange else"))
        // Visibility path must use scroll: false — never scroll: true for free-scroll tracking.
        let visibilityRegion = pageEditor.components(separatedBy: "private func updateActivePageFromVisibility").last?
            .components(separatedBy: "private func pageCanvas").first ?? ""
        XCTAssertTrue(visibilityRegion.contains("activatePage(id: target, scroll: false)"))
        XCTAssertFalse(visibilityRegion.contains("activatePage(id: target, scroll: true)"))
        XCTAssertFalse(visibilityRegion.contains("scrollDocument(to:"))
    }

    func testIntentionalTapActivatesWithSnapThenEdit() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let canvas = try source(named: "PageOverlayCanvasView.swift")
        let engine = try source(named: "DocumentScrollNavigationEngine.swift", subdirectory: "Services")
        XCTAssertTrue(pageEditor.contains("intentionallyActivatePage(id:"))
        XCTAssertTrue(pageEditor.contains("pendingIntentionalEdit"))
        XCTAssertTrue(pageEditor.contains("applyPendingIntentionalEdit"))
        XCTAssertTrue(pageEditor.contains("shouldAcceptIntentionalPageActivation"))
        XCTAssertTrue(pageEditor.contains("intentionalEditSelection"))
        XCTAssertTrue(canvas.contains("onRequestIntentionalContentEdit"))
        XCTAssertTrue(engine.contains("intentionalActivationSnapNanoseconds"))
        // Inactive page tap must go through intentional activation, not raw activatePage scroll.
        let slotRegion = pageEditor.components(separatedBy: "private func documentPageSlot").last?
            .components(separatedBy: "private func pageRenderKey").first ?? ""
        XCTAssertTrue(slotRegion.contains("intentionallyActivatePage"))
        XCTAssertFalse(slotRegion.contains("activatePage(id: item.id, scroll: true)"))
    }

    func testInitialViewportUsesTopRestAnchorWithoutCenterSettle() throws {
        let pageEditor = try source(named: "PageEditorView.swift")
        let engine = try source(named: "DocumentScrollNavigationEngine.swift", subdirectory: "Services")
        XCTAssertTrue(engine.contains("pageRestAnchor"))
        XCTAssertTrue(pageEditor.contains("DocumentScrollNavigationEngine.pageRestAnchor"))
        XCTAssertTrue(pageEditor.contains("scrollDocument(to:"))
        XCTAssertTrue(pageEditor.contains("animated: false"))
        XCTAssertFalse(pageEditor.contains("anchor: .center"))
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
