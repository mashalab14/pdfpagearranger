import PDFKit
import UIKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class TextOverlayCompactFormatBarRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        pdfService = PDFService()
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        pdfService = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Compact toolbar composition

    func testCompactToolbarExposesFiveMenusAndDone() throws {
        let source = try formatBarSource()
        XCTAssertTrue(source.contains("textOverlayCompactToolbar"))
        XCTAssertTrue(source.contains("textFormatAppearanceButton"))
        XCTAssertTrue(source.contains("textFormatStyleButton"))
        XCTAssertTrue(source.contains("textFormatAlignmentButton"))
        XCTAssertTrue(source.contains("textFormatListsButton"))
        XCTAssertTrue(source.contains("textFormatMoreButton"))
        XCTAssertTrue(source.contains("textOverlayEditingDone"))
        XCTAssertTrue(source.contains("enum TextOverlayFormatMenu"))
        XCTAssertTrue(source.contains("case appearance"))
        XCTAssertTrue(source.contains("case style"))
        XCTAssertTrue(source.contains("case alignment"))
        XCTAssertTrue(source.contains("case lists"))
        XCTAssertTrue(source.contains("case more"))
    }

    func testAppearancePanelContainsFontSizeColorOpacity() throws {
        let source = try formatBarSource()
        XCTAssertTrue(source.contains("textFormatAppearancePanel"))
        XCTAssertTrue(source.contains("textFontFamilyMenu"))
        XCTAssertTrue(source.contains("textFontSizeStepper"))
        XCTAssertTrue(source.contains("textColorPicker"))
        XCTAssertTrue(source.contains("textOpacitySlider"))
    }

    func testStylePanelContainsBIUAndStrikethrough() throws {
        let source = try formatBarSource()
        XCTAssertTrue(source.contains("textFormatStylePanel"))
        XCTAssertTrue(source.contains("textBoldToggle"))
        XCTAssertTrue(source.contains("textItalicToggle"))
        XCTAssertTrue(source.contains("textUnderlineToggle"))
        XCTAssertTrue(source.contains("textStrikethroughToggle"))
    }

    func testAlignmentListsAndMorePanelsContainExpectedActions() throws {
        let source = try formatBarSource()
        XCTAssertTrue(source.contains("textFormatAlignmentPanel"))
        XCTAssertTrue(source.contains("textAlignLeft"))
        XCTAssertTrue(source.contains("textAlignCenter"))
        XCTAssertTrue(source.contains("textAlignRight"))
        XCTAssertTrue(source.contains("textFormatListsPanel"))
        XCTAssertTrue(source.contains("textListNone"))
        XCTAssertTrue(source.contains("textBulletedListToggle"))
        XCTAssertTrue(source.contains("textNumberedListToggle"))
        XCTAssertTrue(source.contains("textDashedListToggle"))
        XCTAssertTrue(source.contains("textIndentIncrease"))
        XCTAssertTrue(source.contains("textIndentDecrease"))
        XCTAssertTrue(source.contains("textFormatMorePanel"))
        XCTAssertTrue(source.contains("insertDateButton"))
        XCTAssertTrue(source.contains("textInsertDatePicker"))
        XCTAssertTrue(source.contains("textRecentTextsButton"))
        XCTAssertTrue(source.contains("textFormatDuplicateButton"))
        XCTAssertTrue(source.contains("textFormatResetButton"))
        XCTAssertTrue(source.contains("recentTextsSection"))
        XCTAssertFalse(source.contains("insertTodayButton"))
        XCTAssertFalse(source.contains("Insert Today"))
    }

    func testMenusAreExclusiveSingleOpenMenuState() throws {
        let source = try formatBarSource()
        XCTAssertTrue(source.contains("@State private var openMenu: TextOverlayFormatMenu?"))
        XCTAssertTrue(source.contains("openMenu = isOpen ? nil : menu"))
        XCTAssertTrue(source.contains("focusedPanel(for:"))
        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: 14"))
        // Opening a non-more menu dismisses the Recent Texts sheet path.
        XCTAssertTrue(source.contains("if menu != .more"))
        XCTAssertTrue(source.contains("showRecentTexts = false"))
    }

    func testMenusDismissWhenEditingEnds() throws {
        let source = try formatBarSource()
        XCTAssertTrue(source.contains(".onDisappear"))
        XCTAssertTrue(source.contains("showRecentTexts = false"))
        XCTAssertTrue(source.contains("openMenu = nil"))
    }

    // MARK: - Page editor wiring

    func testAddButtonHiddenWhileTextEditingActive() throws {
        let source = try pageEditorSource()
        // Floating page chrome (capsule + Add FAB) hides while inline text editing is active.
        XCTAssertTrue(source.contains("if !textEditingActive {\n                pageBottomToolbar\n"))
        XCTAssertTrue(source.contains("pageModeAddButton"))
        XCTAssertTrue(source.contains("floatingAddButton"))
        XCTAssertTrue(source.contains("onDuplicate:"))
        XCTAssertTrue(source.contains("onResetFormatting:"))
        XCTAssertTrue(source.contains("resetFormattingPreservingText()"))
        XCTAssertTrue(source.contains("duplicateTextOverlay(id: overlayID"))
    }

    func testDoesNotRestoreObsoleteFullWidthToolbarOrAddTextSheet() throws {
        let formatBar = try formatBarSource()
        let editor = try pageEditorSource()
        // Appearance mode may scroll horizontally inside the same toolbar; root toolbar must not be a full-width strip of every control.
        XCTAssertTrue(formatBar.contains("textOverlayCompactToolbar"))
        XCTAssertTrue(formatBar.contains("focusedPanel(for:"))
        XCTAssertFalse(formatBar.contains("contextualToolbar(for:"))
        XCTAssertFalse(formatBar.contains("ToolbarItemGroup(placement: .keyboard)"))
        XCTAssertFalse(editor.contains("TextOverlayEditorSheet"))
        XCTAssertFalse(editor.contains("showTextOverlayEditor"))
        XCTAssertFalse(editor.contains("textPlacementGuidance"))
        XCTAssertTrue(editor.contains("TextOverlayFormatBar"))
        XCTAssertTrue(editor.contains("beginDraftTextOverlay"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: formatBarURL().path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: projectRoot()
                    .appendingPathComponent("pdfpagearranger/Views/TextOverlayEditorSheet.swift")
                    .path
            )
        )
    }

    // MARK: - Formatting behaviour

    func testResetFormattingPreservesTextAndClearsStyles() {
        var draft = TextOverlayDraft(
            text: "Keep me",
            fontSizePoints: 28,
            isBold: true,
            isItalic: true,
            isUnderline: true,
            isStrikethrough: true,
            alignment: .center,
            listMode: .bulleted,
            listIndent: 2,
            fontFamily: .serif,
            opacity: 0.4,
            spans: [
                TextOverlayTextSpan(text: "Keep ", isBold: true),
                TextOverlayTextSpan(text: "me", isItalic: true)
            ]
        )
        draft.resetFormattingPreservingText()
        XCTAssertEqual(draft.text, "Keep me")
        XCTAssertEqual(draft.fontSizePoints, TextOverlayDraft.defaultFontSizePoints)
        XCTAssertFalse(draft.isBold)
        XCTAssertFalse(draft.isItalic)
        XCTAssertFalse(draft.isUnderline)
        XCTAssertFalse(draft.isStrikethrough)
        XCTAssertEqual(draft.alignment, .left)
        XCTAssertEqual(draft.listMode, .plain)
        XCTAssertEqual(draft.listIndent, 0)
        XCTAssertEqual(draft.fontFamily, .system)
        XCTAssertEqual(draft.opacity, 1, accuracy: 0.001)
        XCTAssertEqual(draft.spans.count, 1)
        XCTAssertEqual(draft.spans.first?.text, "Keep me")
        XCTAssertNil(draft.spans.first?.isBold)
        XCTAssertNil(draft.spans.first?.isItalic)
    }

    func testTypingAttributesApplyWhenNoSelection() {
        var draft = TextOverlayDraft(text: "Hello")
        draft.selectedUTF16Location = 5
        draft.selectedUTF16Length = 0
        draft.applyFormatting(
            updateDefaults: { $0.isBold = true },
            updateSpan: { $0.isBold = true }
        )
        XCTAssertTrue(draft.isBold)
        XCTAssertEqual(draft.spans.first?.isBold, true)
    }

    func testSelectedRangeFormattingDoesNotForceWholeOverlayDefault() {
        var draft = TextOverlayDraft(text: "AB")
        draft.synchronizeSpansWithTextIfNeeded()
        draft.selectedUTF16Location = 0
        draft.selectedUTF16Length = 1
        draft.applyFormatting(
            updateDefaults: { $0.isBold = true },
            updateSpan: { $0.isBold = true }
        )
        XCTAssertFalse(draft.isBold)
        XCTAssertGreaterThanOrEqual(draft.spans.count, 2)
        XCTAssertEqual(draft.spans[0].text, "A")
        XCTAssertEqual(draft.spans[0].isBold, true)
        XCTAssertNotEqual(draft.spans[1].isBold, true)
    }

    func testOpacityAlignmentListsAndInsertTodayUpdateDraft() {
        var draft = TextOverlayDraft(text: "Body")
        draft.opacity = TextOverlayDraft.clampedOpacity(0.25)
        draft.alignment = .right
        draft.listMode = .dashed
        draft.listIndent = 1
        XCTAssertEqual(draft.opacity, 0.25, accuracy: 0.001)
        XCTAssertEqual(draft.alignment, .right)
        XCTAssertEqual(draft.listMode, .dashed)
        XCTAssertEqual(draft.listIndent, 1)

        let withToday = TextOverlayFormattingEngine.appendDate(
            to: draft.text,
            date: Date(timeIntervalSince1970: 1_735_689_600),
            locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(withToday.hasPrefix("Body "))
        XCTAssertGreaterThan(withToday.count, "Body ".count)
    }

    func testDuplicateAndEmptyDraftCancellationStillWork() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let emptyID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertEqual(
            viewModel.commitTextOverlayEditing(
                id: emptyID,
                pageItemID: page.id,
                draft: .default,
                pageAspectRatio: 612.0 / 792.0,
                isNewDraft: true,
                baselineSnapshot: baseline
            ),
            .cancelledEmptyDraft
        )
        XCTAssertTrue(viewModel.overlayObjects(for: page.id).isEmpty)

        let commitBaseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let draft = TextOverlayDraft(text: "Dup me", alignment: .center, opacity: 0.7)
        XCTAssertEqual(
            viewModel.commitTextOverlayEditing(
                id: overlayID,
                pageItemID: page.id,
                draft: draft,
                pageAspectRatio: 612.0 / 792.0,
                isNewDraft: true,
                baselineSnapshot: commitBaseline
            ),
            .committed
        )
        let duplicateID = try XCTUnwrap(viewModel.duplicateOverlay(id: overlayID, pageItemID: page.id))
        let duplicate = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == duplicateID }))
        XCTAssertEqual(duplicate.textContent, "Dup me")
        XCTAssertEqual(duplicate.opacity, 0.7, accuracy: 0.001)
        XCTAssertEqual(duplicate.textAlignment, .center)

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        viewModel.undo()
        XCTAssertTrue(viewModel.overlayObjects(for: page.id).isEmpty)
        viewModel.redo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
    }

    func testPersistenceReopenThumbnailsAndExportPreserveCompactBarFormatting() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        var draft = TextOverlayDraft(
            text: "Persist",
            fontSizePoints: 18,
            isBold: true,
            alignment: .center,
            opacity: 0.6,
            spans: [
                TextOverlayTextSpan(text: "Per", isBold: true),
                TextOverlayTextSpan(text: "sist", isItalic: true)
            ]
        )
        draft.selectedUTF16Location = 0
        draft.selectedUTF16Length = 0
        XCTAssertEqual(
            viewModel.commitTextOverlayEditing(
                id: overlayID,
                pageItemID: page.id,
                draft: draft,
                pageAspectRatio: 612.0 / 792.0,
                isNewDraft: true,
                baselineSnapshot: baseline
            ),
            .committed
        )

        let stored = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        let reopened = TextOverlayDraft(from: stored)
        XCTAssertEqual(reopened.text, "Persist")
        XCTAssertEqual(reopened.opacity, 0.6, accuracy: 0.001)
        XCTAssertEqual(reopened.alignment, .center)
        XCTAssertEqual(reopened.spans.count, 2)

        let base = UIImage(color: .white, size: CGSize(width: 120, height: 160))
        let thumbnail = OverlayCompositor.composite(
            baseImage: base,
            objects: [stored],
            images: [:]
        )
        XCTAssertGreaterThan(thumbnail.size.width, 0)

        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "compact-bar-export",
            overlaysByPage: [page.id: [stored]],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageContainsText("Persist", at: 0, in: exportURL)
    }

    // MARK: - Source helpers

    private func formatBarSource() throws -> String {
        try String(contentsOf: formatBarURL(), encoding: .utf8)
    }

    private func pageEditorSource() throws -> String {
        try String(
            contentsOf: projectRoot().appendingPathComponent("pdfpagearranger/Views/PageEditorView.swift"),
            encoding: .utf8
        )
    }

    private func formatBarURL() -> URL {
        projectRoot().appendingPathComponent("pdfpagearranger/Views/TextOverlayFormatBar.swift")
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private extension UIImage {
    convenience init(color: UIColor, size: CGSize) {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
    }
}
