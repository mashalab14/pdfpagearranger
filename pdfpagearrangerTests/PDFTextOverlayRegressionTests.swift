import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class PDFTextOverlayRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []
    private var recentDefaults: UserDefaults!
    private let recentSuiteName = "PDFTextOverlayRecent-\(UUID().uuidString)"

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        pdfService = PDFService()
        recentDefaults = UserDefaults(suiteName: recentSuiteName)!
        recentDefaults.removePersistentDomain(forName: recentSuiteName)
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        recentDefaults.removePersistentDomain(forName: recentSuiteName)
        recentDefaults = nil
        pdfService = nil
        viewModel = nil
        try await super.tearDown()
    }

    func testAddSingleLineTextAtPosition() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Hello Form"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.25, y: 0.25)
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.id, overlayID)
        XCTAssertEqual(overlay.type, .text)
        XCTAssertEqual(overlay.textContent, "Hello Form")
        XCTAssertEqual(overlay.position.x, 0.25, accuracy: 0.001)
    }

    func testAddMultilineTextPreservesContent() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        _ = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Line A\nLine B"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertTrue(overlay.textContent?.contains("Line A") == true)
        XCTAssertTrue(overlay.textContent?.contains("Line B") == true)
    }

    func testFormattingPersistsOnOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let red = SignatureInkRGBA(red: 1, green: 0, blue: 0, alpha: 1)
        _ = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(
                text: "• Bold item",
                fontSizePoints: 20,
                colorRGBA: red,
                isBold: true,
                listMode: .bulleted
            ),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.textFontSizePoints, 20)
        XCTAssertEqual(overlay.textColorRGBA, red)
        XCTAssertEqual(overlay.textBold, true)
        XCTAssertEqual(overlay.textListMode, .bulleted)
    }

    func testUpdateExistingOverlayInPlace() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Original"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.4, y: 0.4)
        )

        let updated = viewModel.updateTextOverlay(
            id: overlayID,
            pageItemID: page.id,
            draft: TextOverlayDraft(text: "Updated")
        )
        XCTAssertTrue(updated)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.id, overlayID)
        XCTAssertEqual(overlay.textContent, "Updated")
        XCTAssertEqual(overlay.position.x, 0.4, accuracy: 0.001)
    }

    func testEmptyUpdateIsRejected() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Keep me"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )

        let updated = viewModel.updateTextOverlay(
            id: overlayID,
            pageItemID: page.id,
            draft: TextOverlayDraft(text: "   ")
        )
        XCTAssertFalse(updated)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.textContent, "Keep me")
    }

    func testMoveResizeRotateDuplicateDelete() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Transform"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))

        overlay.position = CGPoint(x: 0.2, y: 0.8)
        viewModel.updateOverlay(overlay)
        overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.position.y, 0.8, accuracy: 0.001)

        overlay.size = CGSize(width: 0.5, height: 0.2)
        viewModel.updateOverlay(overlay)
        overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.size.width, 0.5, accuracy: 0.001)

        overlay.rotation = 45
        viewModel.updateOverlay(overlay)
        overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.rotation, 45, accuracy: 0.001)

        let duplicateID = try XCTUnwrap(viewModel.duplicateOverlay(id: overlay.id, pageItemID: page.id))
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 2)

        viewModel.deleteOverlay(id: duplicateID, pageItemID: page.id)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
    }

    func testUndoAndRedoTextMutationsViaUndoStack() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        _ = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Undo me"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)
        XCTAssertTrue(viewModel.canUndo)

        viewModel.undo()
        XCTAssertTrue(viewModel.overlayObjects(for: page.id).isEmpty)
    }

    func testExportIncludesTextAbovePageContent() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let overlay = OverlayTestFactory.makeTextOverlay(
            pageItemID: page.id,
            text: "ExportedOverlayText",
            position: CGPoint(x: 0.5, y: 0.5)
        )

        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "text-overlay-export",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("ExportedOverlayText", at: 0, in: exportURL)
    }

    func testExportPreservesBoldBulletsAndNumbering() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let overlay = OverlayTestFactory.makeTextOverlay(
            pageItemID: page.id,
            text: "• Bullet\n2. Number",
            bold: true,
            listMode: .bulleted
        )

        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "text-overlay-format-export",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)

        let pageText = try XCTUnwrap(PDFDocument(url: exportURL)?.page(at: 0)?.string)
        XCTAssertTrue(pageText.contains("Bullet"))
    }

    func testMixedOverlayTypesExportTogether() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let assetID = UUID()
        let imageOverlay = OverlayTestFactory.makeImageOverlay(pageItemID: page.id, assetID: assetID)
        let textOverlay = OverlayTestFactory.makeTextOverlay(pageItemID: page.id, text: "MixedTextOverlay")

        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "mixed-overlay-export",
            overlaysByPage: [page.id: [imageOverlay, textOverlay]],
            imageAssets: [assetID: PDFTestFactory.makeTestImage(color: .green)]
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText("MixedTextOverlay", at: 0, in: exportURL)
    }

    func testRotatedOverlayClampsWithinPageBounds() {
        let clamped = TextOverlayBoundsEngine.clampDisplayCenter(
            CGPoint(x: 0.02, y: 0.02),
            displaySize: CGSize(width: 0.2, height: 0.1),
            rotationDegrees: 30
        )
        XCTAssertGreaterThanOrEqual(clamped.x, 0)
        XCTAssertGreaterThanOrEqual(clamped.y, 0)
        XCTAssertLessThanOrEqual(clamped.x, 1)
        XCTAssertLessThanOrEqual(clamped.y, 1)
    }

    func testDirectDraftCreationPlacesSelectedEmptyOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baselineCount = viewModel.overlayObjects(for: page.id).count
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.42)
        )

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, baselineCount + 1)
        XCTAssertEqual(overlay.textContent, "")
        XCTAssertFalse(viewModel.canUndo, "Draft creation must not push undo until commit")
    }

    func testEmptyDraftCancellationRemovesOverlayWithoutUndo() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )

        let result = viewModel.commitTextOverlayEditing(
            id: overlayID,
            pageItemID: page.id,
            draft: .default,
            pageAspectRatio: 612.0 / 792.0,
            isNewDraft: true,
            baselineSnapshot: baseline
        )

        XCTAssertEqual(result, .cancelledEmptyDraft)
        XCTAssertTrue(viewModel.overlayObjects(for: page.id).isEmpty)
        XCTAssertFalse(viewModel.canUndo)
    }

    func testPlaceholderNeverPersistedOrExported() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        _ = viewModel.syncTextOverlayDraft(
            id: overlayID,
            pageItemID: page.id,
            draft: .default,
            pageAspectRatio: 612.0 / 792.0
        )
        let live = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertNotEqual(live.textContent, TextOverlayDraft.placeholderHint)

        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "placeholder-exclusion",
            overlaysByPage: [page.id: [live]],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)
        let pageText = PDFDocument(url: exportURL)?.page(at: 0)?.string ?? ""
        XCTAssertFalse(pageText.contains(TextOverlayDraft.placeholderHint))
    }

    func testMultilineWrappingGrowsHeightPreservingWidth() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let initial = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        let width = initial.size.width

        var draft = TextOverlayDraft(text: String(repeating: "Wrapping word ", count: 24))
        _ = viewModel.syncTextOverlayDraft(
            id: overlayID,
            pageItemID: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0,
            preserveWidth: true
        )
        let grown = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(grown.size.width, width, accuracy: 0.0001)
        XCTAssertGreaterThan(grown.size.height, initial.size.height)
    }

    func testLiveFormattingAndAlignmentCommit() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )

        var draft = TextOverlayDraft(
            text: "Live format",
            fontSizePoints: 22,
            colorRGBA: SignatureInkRGBA(red: 0, green: 0, blue: 1, alpha: 1),
            isBold: true,
            isItalic: true,
            isUnderline: true,
            alignment: .right,
            listMode: .numbered,
            listIndent: 1,
            fontFamily: .monospaced
        )
        _ = viewModel.syncTextOverlayDraft(
            id: overlayID,
            pageItemID: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0
        )
        let result = viewModel.commitTextOverlayEditing(
            id: overlayID,
            pageItemID: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0,
            isNewDraft: true,
            baselineSnapshot: baseline
        )
        XCTAssertEqual(result, .committed)

        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first)
        XCTAssertEqual(overlay.textFontSizePoints, 22)
        XCTAssertEqual(overlay.textBold, true)
        XCTAssertEqual(overlay.textItalic, true)
        XCTAssertEqual(overlay.textUnderline, true)
        XCTAssertEqual(overlay.textAlignment, .right)
        XCTAssertEqual(overlay.textListMode, .numbered)
        XCTAssertEqual(overlay.textListIndent, 1)
        XCTAssertEqual(overlay.textFontFamily, .monospaced)
        XCTAssertTrue(overlay.textContent?.contains("1.") == true)
    }

    func testListStylesAndInsertToday() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let withToday = TextOverlayFormattingEngine.appendToday(to: "Note")
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: withToday, listMode: .dashed),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(overlay.textListMode, .dashed)
        XCTAssertTrue(overlay.textContent?.contains("–") == true)
        XCTAssertTrue(overlay.textContent?.contains("Note") == true)
    }

    func testExistingOverlayReeditCommitsUndoably() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "Original"),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.4, y: 0.4)
        )
        let baseline = viewModel.captureEditorSnapshot()
        var draft = TextOverlayDraft(text: "Re-edited")
        _ = viewModel.syncTextOverlayDraft(
            id: overlayID,
            pageItemID: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0
        )
        let result = viewModel.commitTextOverlayEditing(
            id: overlayID,
            pageItemID: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0,
            isNewDraft: false,
            baselineSnapshot: baseline
        )
        XCTAssertEqual(result, .committed)
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.textContent, "Re-edited")

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.textContent, "Original")
    }

    func testCommitDraftRecordsRecentTextsExcludingPlaceholder() throws {
        RecentTextsSettings.clear(in: recentDefaults)
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let draft = TextOverlayDraft(text: "Recent Candidate")
        // Route Recent Texts through standard UserDefaults path used by production.
        let result = viewModel.commitTextOverlayEditing(
            id: overlayID,
            pageItemID: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0,
            isNewDraft: true,
            baselineSnapshot: baseline
        )
        XCTAssertEqual(result, .committed)
        let entries = RecentTextsSettings.storedEntries()
        XCTAssertTrue(entries.contains(where: { $0.contains("Recent Candidate") }))
        XCTAssertFalse(entries.contains(TextOverlayDraft.placeholderHint))
    }

    func testPageModeSourceUsesInlineEditorNotLegacySheet() throws {
        let editorURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/Views/PageEditorView.swift")
        let source = try String(contentsOf: editorURL, encoding: .utf8)
        XCTAssertTrue(source.contains("beginDraftTextOverlay"))
        XCTAssertTrue(source.contains("TextOverlayFormatBar"))
        XCTAssertFalse(source.contains("TextOverlayEditorSheet"))
        XCTAssertFalse(source.contains("textPlacementGuidance"))
        XCTAssertFalse(source.contains("ScrollView(.horizontal"))
        XCTAssertTrue(source.contains("if !textEditingActive"))
    }
}
