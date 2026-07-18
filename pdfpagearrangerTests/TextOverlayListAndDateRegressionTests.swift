import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class TextOverlayListAndDateRegressionTests: XCTestCase {
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

    func testListMarkersVisibleInEditingAttributedString() {
        let draft = TextOverlayDraft(text: "One\nTwo", listMode: .bulleted)
        let editing = TextOverlayLayoutEngine.attributedString(
            for: draft,
            placeholderWhenEmpty: true,
            includeListMarkers: true
        )
        XCTAssertTrue(editing.string.contains("•"))
        XCTAssertTrue(editing.string.contains("One"))
        XCTAssertTrue(editing.string.contains("Two"))

        let emptyList = TextOverlayLayoutEngine.attributedString(
            for: TextOverlayDraft(text: "", listMode: .bulleted),
            placeholderWhenEmpty: true,
            includeListMarkers: true
        )
        XCTAssertTrue(emptyList.string.contains("•"))
        XCTAssertFalse(emptyList.string.contains(TextOverlayDraft.placeholderHint))
    }

    func testEmptyListRowsKeepMarkersAcrossModes() {
        let plain = "Alpha\n\nBeta"
        let bulleted = TextOverlayFormattingEngine.displayText(plain, listMode: .bulleted)
        XCTAssertTrue(bulleted.contains("• Alpha"))
        XCTAssertTrue(bulleted.contains("• "))
        XCTAssertTrue(bulleted.contains("• Beta"))

        let numbered = TextOverlayFormattingEngine.displayText(plain, listMode: .numbered)
        XCTAssertTrue(numbered.contains("1. Alpha"))
        XCTAssertTrue(numbered.contains("2. "))
        XCTAssertTrue(numbered.contains("3. Beta"))

        let dashed = TextOverlayFormattingEngine.displayText(plain, listMode: .dashed)
        XCTAssertTrue(dashed.contains("– Alpha"))
        XCTAssertTrue(dashed.contains("– Beta"))
    }

    func testPlainDisplayLocationRoundTripPreservesCaret() {
        let plain = "Hello\nWorld"
        let displayLoc = TextOverlayListEditingEngine.displayUTF16Location(
            plainLocation: 6,
            plainText: plain,
            listMode: .bulleted,
            listIndent: 0
        )
        let back = TextOverlayListEditingEngine.plainUTF16Location(
            displayLocation: displayLoc,
            plainText: plain,
            listMode: .bulleted,
            listIndent: 0
        )
        XCTAssertEqual(back, 6)
    }

    func testStrippingMarkersFromAttributedEditingText() {
        let draft = TextOverlayDraft(text: "A\nB", listMode: .numbered, listIndent: 1)
        let attributed = TextOverlayLayoutEngine.attributedString(
            for: draft,
            includeListMarkers: true
        )
        let body = TextOverlayListEditingEngine.attributedBodyStrippingMarkers(
            from: attributed,
            listMode: .numbered,
            listIndent: 1
        )
        XCTAssertEqual(body.string, "A\nB")
    }

    func testInlineEditorSourceKeepsListMarkersEnabled() throws {
        let source = try String(
            contentsOf: projectRoot().appendingPathComponent("pdfpagearranger/Views/TextOverlayInlineEditor.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("includeListMarkers: true"))
        XCTAssertFalse(source.contains("includeListMarkers: false"))
        XCTAssertTrue(source.contains("TextOverlayListEditingEngine"))
        XCTAssertTrue(source.contains("attributedBodyStrippingMarkers"))
    }

    func testListPersistenceDuplicateUndoAndExport() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        var draft = TextOverlayDraft(text: "Milk\nEggs", isBold: true, listMode: .bulleted)
        draft.synchronizeSpansWithTextIfNeeded()
        draft.selectedUTF16Location = 0
        draft.selectedUTF16Length = 4
        draft.applyFormatting(
            updateDefaults: { $0.isItalic = true },
            updateSpan: { $0.isItalic = true }
        )

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
        XCTAssertEqual(stored.textListMode, .bulleted)
        let reopened = TextOverlayDraft(from: stored)
        XCTAssertEqual(reopened.text, "Milk\nEggs")
        XCTAssertEqual(reopened.listMode, .bulleted)

        let display = TextOverlayLayoutEngine.attributedString(for: stored)
        XCTAssertTrue(display.string.contains("•"))
        XCTAssertTrue(display.string.contains("Milk"))

        let duplicateID = try XCTUnwrap(viewModel.duplicateOverlay(id: overlayID, pageItemID: page.id))
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 2)
        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        viewModel.redo()
        XCTAssertNotNil(viewModel.overlayObjects(for: page.id).first(where: { $0.id == duplicateID }))

        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "list-edit-export",
            overlaysByPage: [page.id: viewModel.overlayObjects(for: page.id)],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageContainsText("Milk", at: 0, in: exportURL)
        try ExportAssertions.assertPageContainsText("Eggs", at: 0, in: exportURL)
    }

    func testInsertDateAtCaretAndReplaceSelection() {
        var draft = TextOverlayDraft(text: "Hello World", isBold: true)
        draft.selectedUTF16Location = 6
        draft.selectedUTF16Length = 0
        let date = Date(timeIntervalSince1970: 1_735_689_600)
        let formatted = TextOverlayFormattingEngine.localizedDateString(
            date: date,
            locale: Locale(identifier: "en_US")
        )
        draft.insertTextAtSelection(formatted)
        XCTAssertTrue(draft.text.contains(formatted))
        XCTAssertTrue(draft.text.hasPrefix("Hello "))
        XCTAssertEqual(draft.selectedUTF16Length, 0)
        XCTAssertEqual(draft.spans.contains(where: { $0.isBold == true || draft.isBold }), true)

        draft = TextOverlayDraft(text: "Replace ME please")
        draft.selectedUTF16Location = 8
        draft.selectedUTF16Length = 2
        draft.insertTextAtSelection(formatted)
        XCTAssertFalse(draft.text.contains("ME"))
        XCTAssertTrue(draft.text.contains(formatted))
    }

    func testInsertDateToolbarAndMorphingSurfaceGuards() throws {
        let formatBar = try String(
            contentsOf: projectRoot().appendingPathComponent("pdfpagearranger/Views/TextOverlayFormatBar.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(formatBar.contains("insertDateButton"))
        XCTAssertTrue(formatBar.contains("textInsertDatePicker"))
        XCTAssertTrue(formatBar.contains("textInsertDateTodayButton"))
        XCTAssertTrue(formatBar.contains("textInsertDateConfirmButton"))
        XCTAssertTrue(formatBar.contains("case insertDate"))
        XCTAssertTrue(formatBar.contains("focusedPanel(for:"))
        XCTAssertTrue(formatBar.contains("RoundedRectangle(cornerRadius: 14"))
        XCTAssertFalse(formatBar.contains("Insert Today"))
        XCTAssertFalse(formatBar.contains("insertTodayButton"))
        XCTAssertFalse(formatBar.contains("contextualToolbar(for:"))

        let canvas = try String(
            contentsOf: projectRoot().appendingPathComponent("pdfpagearranger/Views/PageOverlayCanvasView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(canvas.contains("keyboardBottomInset - 40"))
        XCTAssertTrue(canvas.contains("* 0.55, 260"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
