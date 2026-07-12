import PDFKit
import XCTest
@testable import pdfpagearranger

@MainActor
final class DocumentSearchRegressionTests: XCTestCase {
    private var viewModel: PDFEditorViewModel!
    private var pdfService: PDFService!
    private var tempURLs: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        viewModel = PDFEditorViewModel()
        pdfService = PDFService()
    }

    override func tearDown() async throws {
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempURLs.removeAll()
        viewModel = nil
        pdfService = nil
        try await super.tearDown()
    }

    func testNativePDFSearchFindsMatches() async throws {
        let url = try PDFTestFactory.writeTextPDF(named: "search-native", text: "Payment reference number")
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
        let document = try XCTUnwrap(viewModel.sourceDocument)

        let results = DocumentSearchEngine.search(
            query: "reference",
            in: document,
            pages: viewModel.pages
        )

        XCTAssertEqual(results.matches.count, 1)
        XCTAssertTrue(results.matches[0].matchedText.localizedCaseInsensitiveContains("reference"))
    }

    func testSearchIsCaseInsensitive() async throws {
        let url = try PDFTestFactory.writeTextPDF(named: "search-case", text: "Merchant PAYMENT details")
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
        let document = try XCTUnwrap(viewModel.sourceDocument)

        let results = DocumentSearchEngine.search(
            query: "payment",
            in: document,
            pages: viewModel.pages
        )

        XCTAssertEqual(results.matches.count, 1)
    }

    func testEmptyQueryReturnsNoMatches() async throws {
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
        let document = try XCTUnwrap(viewModel.sourceDocument)

        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery("   ")

        XCTAssertTrue(viewModel.documentSearch.results.matches.isEmpty)
        XCTAssertNil(viewModel.documentSearch.currentMatchIndex)

        let directResults = DocumentSearchEngine.search(
            query: " ",
            in: document,
            pages: viewModel.pages
        )
        XCTAssertTrue(directResults.matches.isEmpty)
    }

    func testNoResultState() async throws {
        let url = try PDFTestFactory.writeTextPDF(named: "search-empty", text: "Alpha beta gamma")
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery("zzzz-not-found")

        XCTAssertFalse(viewModel.documentSearch.results.hasMatches)
        XCTAssertNil(viewModel.documentSearch.currentMatchIndex)
    }

    func testMultipleMatchesAcrossPages() async throws {
        let url = try PDFTestFactory.writePDF(
            named: "search-multipage",
            pageCount: 3,
            labels: [
                "Payment on page one",
                "Another payment on page two",
                "No match here"
            ]
        )
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
        let document = try XCTUnwrap(viewModel.sourceDocument)

        let results = DocumentSearchEngine.search(
            query: "payment",
            in: document,
            pages: viewModel.pages
        )

        XCTAssertEqual(results.matches.count, 2)
        XCTAssertEqual(results.matches[0].pageNumber, 1)
        XCTAssertEqual(results.matches[1].pageNumber, 2)
    }

    func testNextAndPreviousMatchNavigateAcrossPages() async throws {
        let url = try PDFTestFactory.writePDF(
            named: "search-nav",
            pageCount: 2,
            labels: ["First payment", "Second payment"]
        )
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery("payment")
        viewModel.selectDocumentSearchMatch(at: 0)

        let first = try XCTUnwrap(viewModel.documentSearch.currentMatch)
        XCTAssertEqual(first.pageNumber, 1)

        let second = try XCTUnwrap(viewModel.moveToNextDocumentSearchMatch())
        XCTAssertEqual(second.pageNumber, 2)

        let wrapped = try XCTUnwrap(viewModel.moveToNextDocumentSearchMatch())
        XCTAssertEqual(wrapped.pageNumber, 1)

        let previous = try XCTUnwrap(viewModel.moveToPreviousDocumentSearchMatch())
        XCTAssertEqual(previous.pageNumber, 2)
    }

    func testSearchResetsAfterNewPDFImport() async throws {
        let firstURL = try PDFTestFactory.writeTextPDF(named: "search-first", text: "FindMe")
        let secondURL = try PDFTestFactory.writeTextPDF(named: "search-second", text: "Other")
        tempURLs.append(contentsOf: [firstURL, secondURL])

        await viewModel.importPDF(from: firstURL)
        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery("FindMe")
        XCTAssertEqual(viewModel.documentSearch.results.matchCount, 1)

        await viewModel.importPDF(from: secondURL)

        XCTAssertFalse(viewModel.documentSearch.isActive)
        XCTAssertTrue(viewModel.documentSearch.results.matches.isEmpty)
    }

    func testSearchDoesNotAffectUndoStack() async throws {
        let url = try PDFTestFactory.url(for: .onePage)
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
        let page = try XCTUnwrap(viewModel.pages.first)

        viewModel.addImageOverlay(
            to: page.id,
            image: PDFTestFactory.makeTestImage(),
            pageAspectRatio: 612.0 / 792.0
        )
        XCTAssertTrue(viewModel.canUndo)

        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery("anything")
        _ = viewModel.moveToNextDocumentSearchMatch()

        XCTAssertTrue(viewModel.canUndo)
        viewModel.undo()
        XCTAssertEqual(viewModel.overlayObjects(for: page.id).count, 0)
    }

    func testSearchDoesNotAffectExport() async throws {
        let expectedText = "ExportSearchText"
        let sourceURL = try PDFTestFactory.writeTextPDF(named: "search-export", text: expectedText)
        tempURLs.append(sourceURL)
        let imported = try pdfService.importPDF(from: sourceURL)
        tempURLs.append(imported.localURL)
        let pages = pdfService.makeInitialPages(pageCount: 1)

        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery(expectedText)

        let exportURL = try pdfService.exportPDF(
            pages: pages,
            sourceDocument: imported.document,
            outputName: "search-export-output"
        )
        tempURLs.append(exportURL)

        try ExportAssertions.assertPageContainsText(expectedText, at: 0, in: exportURL)
    }

    func testOCRSearchablePDFTextIsSearchable() async throws {
        let url = try PDFTestFactory.writeTextPDF(named: "ocr-searchable", text: "SearchableScanText")
        tempURLs.append(url)
        await viewModel.importPDF(from: url)
        let document = try XCTUnwrap(viewModel.sourceDocument)

        let results = DocumentSearchEngine.search(
            query: "SearchableScan",
            in: document,
            pages: viewModel.pages
        )

        XCTAssertEqual(results.matches.count, 1)
        XCTAssertFalse(results.matches[0].contextSnippet.isEmpty)
    }

    func testSearchHighlightRendererDrawsDistinctRects() throws {
        let match = DocumentSearchMatch(
            globalIndex: 0,
            pageItemID: UUID(),
            pageNumber: 1,
            matchedText: "pay",
            contextSnippet: "…payment…",
            normalizedRects: [PageNormalizedRect(x: 0.2, y: 0.3, width: 0.2, height: 0.04)]
        )
        let size = CGSize(width: 300, height: 400)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            SearchHighlightRenderer.drawHighlights(
                matches: [match],
                activeMatchID: match.id,
                pageRotation: 0,
                renderSize: size,
                in: context.cgContext,
                coordinateSpace: .topLeftOrigin
            )
        }

        let color = try XCTUnwrap(ImageTestHelpers.averageColor(
            in: image,
            rect: CGRect(x: 80, y: 118, width: 20, height: 10)
        ))
        XCTAssertGreaterThan(color.red, 0.5)
        XCTAssertGreaterThan(color.green, 0.3)
    }

    func testGroupedResultsPreservePageNumbersAfterReorder() async throws {
        let url = try PDFTestFactory.writePDF(
            named: "search-group",
            pageCount: 2,
            labels: ["Alpha payment", "Beta payment"]
        )
        tempURLs.append(url)
        await viewModel.importPDF(from: url)

        viewModel.openDocumentSearch()
        viewModel.updateDocumentSearchQuery("payment")
        XCTAssertEqual(viewModel.documentSearch.results.groupedByPage().count, 2)

        viewModel.reorderPage(from: 0, to: 1)
        viewModel.refreshDocumentSearchIfNeeded()

        let groups = viewModel.documentSearch.results.groupedByPage()
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.pageNumber)), Set([1, 2]))
    }
}

final class DocumentSearchUIRegressionTests: XCTestCase {
    func testDocumentModeIncludesSearchButton() throws {
        let source = try String(
            contentsOf: sourcePath("Views/EditorView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("documentModeSearchButton"))
        XCTAssertTrue(source.contains("DocumentSearchSheet"))
    }

    func testPageModeIncludesSearchBarAndHighlights() throws {
        let editorSource = try String(
            contentsOf: sourcePath("Views/PageEditorView.swift"),
            encoding: .utf8
        )
        let canvasSource = try String(
            contentsOf: sourcePath("Views/PageOverlayCanvasView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(editorSource.contains("PageModeSearchBar"))
        XCTAssertTrue(editorSource.contains("pageModeSearchButton"))
        XCTAssertTrue(canvasSource.contains("SearchHighlightCanvasLayer"))
        XCTAssertTrue(canvasSource.contains("searchHighlightLayer"))
    }

    func testSearchStateIsNotStoredInUndoSnapshot() throws {
        let snapshotSource = try String(
            contentsOf: sourcePath("Models/EditorSnapshot.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(snapshotSource.contains("documentSearch"))
        XCTAssertFalse(snapshotSource.contains("DocumentSearch"))
    }

    private func sourcePath(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pdfpagearranger/\(relative)")
    }
}
