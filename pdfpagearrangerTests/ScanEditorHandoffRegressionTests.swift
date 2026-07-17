import XCTest
@testable import pdfpagearranger

@MainActor
final class ScanEditorHandoffRegressionTests: XCTestCase {
    func testHandoffUsesExistingEditorImportFlow() async throws {
        let pdfURL = try PDFTestFactory.url(for: .onePage)
        let editorViewModel = PDFEditorViewModel()
        let handoff = ScanEditorHandoffService()

        try await handoff.handoff(pdfURL: pdfURL, to: editorViewModel)

        XCTAssertTrue(editorViewModel.hasDocument)
        XCTAssertEqual(editorViewModel.pageCount, 1)
        XCTAssertNil(editorViewModel.errorMessage)
    }

    func testHandoffFailsForUnreadablePDF() async throws {
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid-\(UUID().uuidString).pdf")
        try Data("not a pdf".utf8).write(to: invalidURL)

        let editorViewModel = PDFEditorViewModel()
        let handoff = ScanEditorHandoffService()

        do {
            try await handoff.handoff(pdfURL: invalidURL, to: editorViewModel)
            XCTFail("Expected editor handoff failure")
        } catch let error as ScanDraftError {
            XCTAssertEqual(error, .editorHandoffFailure)
        }

        XCTAssertFalse(editorViewModel.hasDocument)
    }

    func testScanDraftNavigationRoutesAreDefined() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Models/ScanDraftRoute.swift")
        )

        XCTAssertTrue(source.contains("case cameraAcquisition"))
        XCTAssertTrue(source.contains("case photosAcquisition"))
        XCTAssertFalse(source.contains("case draftReview"))
        XCTAssertTrue(source.contains("case pageAdjustment"))
        XCTAssertTrue(source.contains("case pdfGenerationProgress"))
        XCTAssertFalse(source.contains("case sourceSelection"))
        XCTAssertFalse(source.contains("case entry"))
    }

    func testContentViewExposesDirectScanEntryPoints() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/ContentView.swift")
        )

        XCTAssertTrue(source.contains("HomeScreenCopy"))
        XCTAssertTrue(source.contains("HomeScreenCopy.scanToPDF"))
        XCTAssertTrue(source.contains("HomeScreenCopy.photoToPDF"))
        XCTAssertTrue(source.contains("HomeScreenCopy.openDocument"))
        XCTAssertTrue(source.contains("ScanDraftRootView"))
        XCTAssertTrue(source.contains("importPDF(from: url)"))
    }
}
