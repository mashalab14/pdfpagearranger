import XCTest
@testable import pdfpagearranger

final class ProGateRegressionTests: XCTestCase {
    func testFreeExportLimitIsTwentyPages() {
        XCTAssertEqual(ProGate.freePageExportLimit, 20)
    }

    func testRequiresPaywallOnlyWhenOverLimitAndNotUnlocked() {
        let gate = ProGate()
        XCTAssertFalse(gate.requiresPaywall(pageCount: 20))
        XCTAssertFalse(gate.requiresPaywall(pageCount: 1))
        XCTAssertTrue(gate.requiresPaywall(pageCount: 21))

        gate.unlockForDevelopment()
        XCTAssertFalse(gate.requiresPaywall(pageCount: 21))
        XCTAssertTrue(gate.canExport(pageCount: 100))
    }

    func testUnlockIsSessionOnlyUntilReset() {
        let gate = ProGate()
        gate.unlockForDevelopment()
        XCTAssertTrue(gate.isProUnlocked)

        gate.isProUnlocked = false
        XCTAssertTrue(gate.requiresPaywall(pageCount: 21))
    }
}

@MainActor
final class ExportPaywallViewModelRegressionTests: XCTestCase {
    func testShouldShowPaywallForExportTracksPageCountAndUnlock() async throws {
        let labels = (1...21).map { "Page \($0)" }
        let url = try PDFTestFactory.writePDF(named: "PaywallPages", pageCount: 21, labels: labels)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = PDFEditorViewModel(
            recentDocumentsStore: RecentDocumentsStore(
                rootDirectory: FileManager.default.temporaryDirectory
                    .appendingPathComponent("PaywallRecent-\(UUID().uuidString)", isDirectory: true)
            )
        )
        await viewModel.importPDF(from: url)
        XCTAssertEqual(viewModel.pageCount, 21)
        XCTAssertTrue(viewModel.shouldShowPaywallForExport())

        viewModel.proGate.unlockForDevelopment()
        XCTAssertFalse(viewModel.shouldShowPaywallForExport())
    }

    func testEditorExportPathGatesOnPaywall() throws {
        let editorSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Views/EditorView.swift")
        )
        XCTAssertTrue(editorSource.contains("shouldShowPaywallForExport()"))
        XCTAssertTrue(editorSource.contains("showPaywall = true"))
        XCTAssertTrue(editorSource.contains("PaywallView"))
    }

    func testCompressionViewDoesNotGateShareOnPaywall() throws {
        let compressionSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("pdfpagearranger/Views/CompressionView.swift")
        )
        XCTAssertFalse(compressionSource.contains("shouldShowPaywallForExport"))
        XCTAssertFalse(compressionSource.contains("ProGate"))
        XCTAssertFalse(compressionSource.contains("PaywallView"))
        XCTAssertTrue(compressionSource.contains("compressionShareButton"))
        XCTAssertTrue(compressionSource.contains("adoptCompressedPDF"))
    }

    func testPrepareCompressionSucceedsForOverLimitDocumentWithoutUnlock() async throws {
        let labels = (1...21).map { "Page \($0)" }
        let url = try PDFTestFactory.writePDF(named: "CompressOverLimit", pageCount: 21, labels: labels)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = PDFEditorViewModel(
            recentDocumentsStore: RecentDocumentsStore(
                rootDirectory: FileManager.default.temporaryDirectory
                    .appendingPathComponent("CompressPaywall-\(UUID().uuidString)", isDirectory: true)
            )
        )
        await viewModel.importPDF(from: url)
        XCTAssertTrue(viewModel.shouldShowPaywallForExport())

        let prepared = try await viewModel.prepareCompressionInput()
        XCTAssertGreaterThan(prepared.byteCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.exportURL.path))
    }
}
