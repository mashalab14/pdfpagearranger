import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class TextOverlayOpacityAndRichTextRegressionTests: XCTestCase {
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

    func testLiveOpacityChangesPersistOnOverlay() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        var draft = TextOverlayDraft(text: "Opaque", opacity: 0.4)
        XCTAssertTrue(
            viewModel.syncTextOverlayDraft(
                id: overlayID,
                pageItemID: page.id,
                draft: draft,
                pageAspectRatio: 612.0 / 792.0
            )
        )
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.opacity ?? 1, 0.4, accuracy: 0.001)
    }

    func testOpacityCommitUndoAndDuplicate() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let baseline = viewModel.captureEditorSnapshot()
        let overlayID = viewModel.beginDraftTextOverlay(
            to: page.id,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let draft = TextOverlayDraft(text: "Fade", opacity: 0.55)
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
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.opacity ?? 1, 0.55, accuracy: 0.001)

        let duplicateID = try XCTUnwrap(viewModel.duplicateOverlay(id: overlayID, pageItemID: page.id))
        let duplicate = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == duplicateID }))
        XCTAssertEqual(duplicate.opacity, 0.55, accuracy: 0.001)

        viewModel.undo() // undo duplicate
        viewModel.undo() // undo commit → remove overlay
        XCTAssertTrue(viewModel.overlayObjects(for: page.id).isEmpty)
        viewModel.redo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).first?.opacity ?? 1, 0.55, accuracy: 0.001)
    }

    func testOpacityRoundTripViaDraftReloadAndExport() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "ExportOpacity", opacity: 0.35),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        let reloaded = TextOverlayDraft(from: overlay)
        XCTAssertEqual(reloaded.opacity, 0.35, accuracy: 0.001)

        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "opacity-export",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageContainsText("ExportOpacity", at: 0, in: exportURL)
    }

    func testSelectedRangeFormattingCreatesMultipleSpans() throws {
        var draft = TextOverlayDraft(text: "HelloWorld")
        draft.synchronizeSpansWithTextIfNeeded()
        draft.selectedUTF16Location = 0
        draft.selectedUTF16Length = 5
        draft.applyFormatting(
            updateDefaults: { $0.isBold = true },
            updateSpan: { $0.isBold = true }
        )
        XCTAssertGreaterThanOrEqual(draft.spans.count, 2)
        XCTAssertEqual(draft.spans[0].text, "Hello")
        XCTAssertEqual(draft.spans[0].isBold, true)
        XCTAssertEqual(draft.spans[1].text, "World")
        XCTAssertNotEqual(draft.spans[1].isBold, true)
    }

    func testTypingAttributesWithNoSelectionUpdateDefaults() throws {
        var draft = TextOverlayDraft(text: "Typed")
        draft.selectedUTF16Location = 5
        draft.selectedUTF16Length = 0
        draft.applyFormatting(
            updateDefaults: { $0.isItalic = true },
            updateSpan: { $0.isItalic = true }
        )
        XCTAssertTrue(draft.isItalic)
        XCTAssertEqual(draft.spans.first?.isItalic, true)
    }

    func testRichTextPersistenceDuplicationUndoAndExport() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        var draft = TextOverlayDraft(text: "BoldPlain")
        draft.synchronizeSpansWithTextIfNeeded()
        draft.selectedUTF16Location = 0
        draft.selectedUTF16Length = 4
        draft.applyFormatting(
            updateDefaults: { $0.isBold = true },
            updateSpan: { $0.isBold = true }
        )
        draft.selectedUTF16Location = 4
        draft.selectedUTF16Length = 5
        draft.applyFormatting(
            updateDefaults: { $0.colorRGBA = SignatureInkRGBA(red: 1, green: 0, blue: 0, alpha: 1) },
            updateSpan: { $0.colorRGBA = SignatureInkRGBA(red: 1, green: 0, blue: 0, alpha: 1) }
        )

        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: draft,
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        let overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        XCTAssertEqual(overlay.textSpans?.count ?? 0, 2)

        let reopened = TextOverlayDraft(from: overlay)
        XCTAssertEqual(reopened.spans.count, 2)
        XCTAssertEqual(reopened.spans[0].isBold, true)

        let duplicateID = try XCTUnwrap(viewModel.duplicateOverlay(id: overlayID, pageItemID: page.id))
        let duplicate = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == duplicateID }))
        XCTAssertEqual(duplicate.textSpans?.count, overlay.textSpans?.count)

        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 1)

        let attributed = TextOverlayLayoutEngine.attributedString(for: overlay)
        XCTAssertTrue(attributed.string.contains("Bold"))
        XCTAssertTrue(attributed.string.contains("Plain"))

        let sourceURL = try PDFTestFactory.url(for: .onePage)
        let imported = try pdfService.importPDF(from: sourceURL)
        let exportURL = try pdfService.exportPDF(
            pages: viewModel.pages,
            sourceDocument: imported.document,
            outputName: "rich-text-export",
            overlaysByPage: [page.id: [overlay]],
            imageAssets: [:]
        )
        tempURLs.append(exportURL)
        try ExportAssertions.assertPageContainsText("BoldPlain", at: 0, in: exportURL)
    }

    func testPlainTextOverlayRemainsCompatibleWithoutSpans() throws {
        let page = try XCTUnwrap(viewModel.pages.first)
        let overlayID = viewModel.addTextOverlay(
            to: page.id,
            draft: TextOverlayDraft(text: "LegacyPlain", isBold: true),
            pageAspectRatio: 612.0 / 792.0,
            at: CGPoint(x: 0.5, y: 0.5)
        )
        var overlay = try XCTUnwrap(viewModel.overlayObjects(for: page.id).first(where: { $0.id == overlayID }))
        overlay.textSpans = nil
        viewModel.updateOverlay(overlay)

        let attributed = TextOverlayLayoutEngine.attributedString(for: overlay)
        XCTAssertEqual(attributed.string, "LegacyPlain")
        let font = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testRegressionSuiteIncludesRichTextAndOpacityTests() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(atPath: testsURL.path)
        XCTAssertTrue(files.contains("TextOverlayOpacityAndRichTextRegressionTests.swift"))
        XCTAssertTrue(files.contains("PDFTextOverlayRegressionTests.swift"))

        let scriptURL = testsURL
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/run-full-regression.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        XCTAssertTrue(script.contains("test"))
        XCTAssertFalse(script.contains("-only-testing:"))
    }
}
