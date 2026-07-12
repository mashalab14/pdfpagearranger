import PDFKit
import XCTest
@testable import pdfpagearranger

final class ScanDraftPDFGeneratorRegressionTests: XCTestCase {
    func testSinglePagePDFGenerationUsesProcessedImage() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let page = try XCTUnwrap(document.pages.first)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)

        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "Single Page",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )
        let pdfURL = result.url

        let pdfDocument = try XCTUnwrap(PDFDocument(url: pdfURL))
        XCTAssertEqual(pdfDocument.pageCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path))
        XCTAssertFalse(pdfURL.lastPathComponent.contains(".staging"))
    }

    func testMultiPagePDFPreservesOrderAndCount() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 4, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        var processedPages: [ScanDraftPage] = []
        for page in document.pages {
            let result = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
            processedPages.append(result.page)
        }

        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)
        let result = try await generator.generatePDF(
            from: processedPages,
            sessionDirectory: sessionDirectory,
            displayName: "Ordered Pages",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )
        let pdfURL = result.url

        let pdfDocument = try XCTUnwrap(PDFDocument(url: pdfURL))
        XCTAssertEqual(pdfDocument.pageCount, 4)
        XCTAssertEqual(processedPages.map(\.id), document.pages.map(\.id))
    }

    func testMixedSourcePagesGenerateSinglePDF() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 3, storage: storage)
        XCTAssertTrue(document.pages.contains(where: { $0.sourceType == .camera }))
        XCTAssertTrue(document.pages.contains(where: { $0.sourceType == .photos }))

        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        var processedPages: [ScanDraftPage] = []
        for page in document.pages {
            let result = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
            processedPages.append(result.page)
        }

        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)
        let result = try await generator.generatePDF(
            from: processedPages,
            sessionDirectory: sessionDirectory,
            displayName: "Mixed Sources",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        XCTAssertEqual(PDFDocument(url: result.url)?.pageCount, 3)
    }

    func testRotatedPagePreservesOrientationInPDF() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        var document = ScanDraftDocument()
        let sessionDirectory = try storage.createSessionDirectory(for: document.id)
        let pageID = UUID()

        let portraitData = ScanDraftTestFactory.makeTestImageData(
            size: CGSize(width: 200, height: 300)
        )
        var page = try storage.importOriginalImage(
            data: portraitData,
            pageID: pageID,
            sourceType: .camera,
            sessionDirectory: sessionDirectory
        )
        page.geometry.rotation = 90
        document.addPage(page)

        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)
        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "Rotated",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        let pdfPage = try XCTUnwrap(PDFDocument(url: result.url)?.page(at: 0))
        let bounds = pdfPage.bounds(for: .mediaBox)
        XCTAssertGreaterThan(bounds.width, bounds.height)
    }

    func testGenerationSkipsReprocessingWhenOutputIsValid() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 2, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        var processedPages: [ScanDraftPage] = []
        for page in document.pages {
            let result = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
            processedPages.append(result.page)
        }
        let fingerprints = processedPages.map(\.processingFingerprint)

        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)
        _ = try await generator.generatePDF(
            from: processedPages,
            sessionDirectory: sessionDirectory,
            displayName: "Cached",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        XCTAssertEqual(processedPages.map(\.processingFingerprint), fingerprints)
    }

    func testTwentyPageGenerationSucceeds() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 20, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        var processedPages: [ScanDraftPage] = []
        for page in document.pages {
            let result = try await orchestrator.processPage(page, sessionDirectory: sessionDirectory)
            processedPages.append(result.page)
        }

        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)
        let result = try await generator.generatePDF(
            from: processedPages,
            sessionDirectory: sessionDirectory,
            displayName: "Twenty Pages",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )

        XCTAssertEqual(PDFDocument(url: result.url)?.pageCount, 20)
    }

    func testAtomicWriteRemovesStagingFile() async throws {
        let storage = ScanDraftTestFactory.makeIsolatedStorage()
        let (document, _, sessionDirectory) = try ScanDraftTestFactory.makeDraftWithPages(count: 1, storage: storage)
        let orchestrator = ScanPageProcessingOrchestrator(storage: storage)
        let processed = try await orchestrator.processPage(
            try XCTUnwrap(document.pages.first),
            sessionDirectory: sessionDirectory
        )
        let generator = ScanDraftPDFGenerator(storage: storage, processingOrchestrator: orchestrator)

        let result = try await generator.generatePDF(
            from: [processed.page],
            sessionDirectory: sessionDirectory,
            displayName: "Atomic",
            options: ScanDraftPDFGenerationOptions(makeSearchable: false, ocrConfiguration: .default),
            onProgress: nil,
            onPagePrepared: nil
        )
        let pdfURL = result.url

        let generatedDirectory = sessionDirectory.appendingPathComponent("generated", isDirectory: true)
        let stagingFiles = try FileManager.default.contentsOfDirectory(at: generatedDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains(".staging.pdf") }
        XCTAssertTrue(stagingFiles.isEmpty)
        XCTAssertTrue(pdfURL.lastPathComponent.hasSuffix(".pdf"))
    }
}

@MainActor
final class ScanDraftPDFGenerationViewModelRegressionTests: XCTestCase {
    private var storage: ScanDraftSessionStorage!
    private var viewModel: ScanDraftSessionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        storage = ScanDraftTestFactory.makeIsolatedStorage()
        viewModel = ScanDraftSessionViewModel(storage: storage)
    }

    func testGeneratePDFKeepsDraftAndProcessedPagesIntact() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 2)
        try await waitForProcessingToFinish()

        let draftID = try XCTUnwrap(viewModel.document?.id)
        let pageIDs = try XCTUnwrap(viewModel.document?.pages.map(\.id))
        let processedPaths = try XCTUnwrap(viewModel.document?.pages.compactMap(\.processedImage?.relativePath))
        let fingerprintsBefore = try XCTUnwrap(viewModel.document?.pages.map(\.processingFingerprint))

        _ = try await viewModel.generatePDF()

        XCTAssertEqual(viewModel.document?.id, draftID)
        XCTAssertEqual(viewModel.document?.pages.map(\.id), pageIDs)
        XCTAssertEqual(viewModel.document?.pages.compactMap(\.processedImage?.relativePath), processedPaths)
        XCTAssertEqual(viewModel.document?.pages.map(\.processingFingerprint), fingerprintsBefore)
        XCTAssertNotNil(viewModel.document?.generatedPDFURL)
        XCTAssertTrue(storage.sessionExists(for: draftID))
    }

    func testHandoffOpensExistingEditorWithoutDeletingDraft() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        try await waitForProcessingToFinish()

        let draftID = try XCTUnwrap(viewModel.document?.id)
        let editorViewModel = PDFEditorViewModel()
        _ = try await viewModel.generatePDF()
        try await viewModel.handoffToEditor(editorViewModel: editorViewModel)

        XCTAssertTrue(editorViewModel.hasDocument)
        XCTAssertEqual(editorViewModel.pageCount, 1)
        XCTAssertNotNil(viewModel.document)
        XCTAssertEqual(viewModel.document?.id, draftID)
        XCTAssertTrue(storage.sessionExists(for: draftID))
    }

    func testFailedGenerationPreservesDraftAndCleansStaging() async throws {
        let failingViewModel = ScanDraftSessionViewModel(
            storage: storage,
            pdfGenerator: UnimplementedScanDraftPDFGenerator()
        )
        try failingViewModel.beginNewDocumentFlow()
        XCTAssertTrue(failingViewModel.requestPhotosImport(context: .newDocument))
        await failingViewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: 1),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: 1)
        )
        try await waitForProcessingToFinish(on: failingViewModel)

        let draftID = try XCTUnwrap(failingViewModel.document?.id)
        let processedPath = try XCTUnwrap(failingViewModel.document?.pages.first?.processedImage?.relativePath)

        do {
            _ = try await failingViewModel.generatePDF()
            XCTFail("Expected generation failure")
        } catch {
            XCTAssertEqual(error as? ScanDraftError, .pdfGenerationFailure)
        }

        XCTAssertNil(failingViewModel.document?.generatedPDFURL)
        XCTAssertEqual(failingViewModel.document?.id, draftID)
        XCTAssertEqual(failingViewModel.document?.pages.first?.processedImage?.relativePath, processedPath)
        XCTAssertTrue(storage.sessionExists(for: draftID))

        let generatedDirectory = storage.sessionDirectory(for: draftID)
            .appendingPathComponent("generated", isDirectory: true)
        if FileManager.default.fileExists(atPath: generatedDirectory.path) {
            let stagingFiles = try FileManager.default.contentsOfDirectory(
                at: generatedDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.contains(".staging.pdf") }
            XCTAssertTrue(stagingFiles.isEmpty)
        }
    }

    func testDuplicateGenerationRequestsAreIgnored() async throws {
        try viewModel.beginNewDocumentFlow()
        await importPhotos(count: 1)
        try await waitForProcessingToFinish()

        let editorViewModel = PDFEditorViewModel()
        var successCount = 0
        viewModel.createPDFAndOpenEditor(editorViewModel: editorViewModel) {
            successCount += 1
        }
        viewModel.createPDFAndOpenEditor(editorViewModel: editorViewModel) {
            successCount += 1
        }

        try await waitForEditorHandoff(editorViewModel: editorViewModel)

        XCTAssertEqual(successCount, 1)
        XCTAssertTrue(editorViewModel.hasDocument)
    }

    private func importPhotos(count: Int) async {
        XCTAssertTrue(viewModel.requestPhotosImport(context: .newDocument))
        await viewModel.handlePhotosSelection(
            orderedItems: ScanPhotosImportTestSupport.makeOrderedItems(count: count),
            assetLoader: ScanPhotosImportTestSupport.makeLoader(count: count)
        )
    }

    private func waitForProcessingToFinish(
        on model: ScanDraftSessionViewModel? = nil,
        timeoutNanoseconds: UInt64 = 3_000_000_000
    ) async throws {
        guard let target = model ?? viewModel else {
            XCTFail("Missing view model")
            return
        }
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if target.isProcessingPages == false,
               target.document?.pages.allSatisfy({ $0.processingState == .ready }) == true {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for page processing")
    }

    private func waitForPDFGenerationToFinish(timeoutNanoseconds: UInt64 = 5_000_000_000) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if viewModel.isGeneratingPDF == false,
               viewModel.document?.generatedPDFURL != nil {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for PDF generation")
    }

    private func waitForEditorHandoff(
        editorViewModel: PDFEditorViewModel,
        timeoutNanoseconds: UInt64 = 5_000_000_000
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if editorViewModel.hasDocument {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Timed out waiting for editor handoff")
    }
}
