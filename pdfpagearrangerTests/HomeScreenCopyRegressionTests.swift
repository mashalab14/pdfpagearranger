import XCTest
@testable import pdfpagearranger

final class HomeScreenCopyRegressionTests: XCTestCase {
    func testHomeScreenCopyUsesOutcomeFocusedLabels() {
        XCTAssertEqual(HomeScreenCopy.openDocument, "Open PDF")
        XCTAssertEqual(HomeScreenCopy.createDocument, "Create PDF")
        XCTAssertEqual(HomeScreenCopy.scanToPDF, "Scan to PDF")
        XCTAssertEqual(HomeScreenCopy.photoToPDF, "Photo to PDF")
        XCTAssertEqual(HomeScreenCopy.recentDocuments, "Recent Documents")
        XCTAssertEqual(HomeScreenCopy.subtitle, "Scan, convert and edit PDFs.")
    }

    func testHomeScreenCopyProvidesAccessibilityHints() {
        XCTAssertFalse(HomeScreenCopy.openDocumentAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.createDocumentAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.scanToPDFAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.photoToPDFAccessibilityHint.isEmpty)
        XCTAssertFalse(HomeScreenCopy.recentDocumentsMoreAccessibilityHint.isEmpty)
    }
}

final class HomeScreenLayoutRegressionTests: XCTestCase {
    private func contentViewSource() throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent("pdfpagearranger/ContentView.swift"),
            encoding: .utf8
        )
    }

    func testHomeLayoutPrioritizesPrimaryActionsOverBrandingAndRecent() throws {
        let source = try contentViewSource()
        let emptyState = source.components(separatedBy: "private var emptyState").last?
            .components(separatedBy: "private var homeHeader").first ?? ""
        XCTAssertTrue(emptyState.contains("homeHeader"))
        XCTAssertTrue(emptyState.contains("acquisitionActions"))
        XCTAssertTrue(emptyState.contains("recentDocumentsSection"))

        let headerIndex = emptyState.range(of: "homeHeader")?.lowerBound
        let actionsIndex = emptyState.range(of: "acquisitionActions")?.lowerBound
        let recentIndex = emptyState.range(of: "recentDocumentsSection")?.lowerBound
        XCTAssertNotNil(headerIndex)
        XCTAssertNotNil(actionsIndex)
        XCTAssertNotNil(recentIndex)
        if let headerIndex, let actionsIndex, let recentIndex {
            XCTAssertLessThan(headerIndex, actionsIndex)
            XCTAssertLessThan(actionsIndex, recentIndex)
        }
    }

    func testCompactHeaderUsesSmallerIconAndSingleLineSubtitle() throws {
        let source = try contentViewSource()
        let header = source.components(separatedBy: "private var homeHeader").last?
            .components(separatedBy: "private var recentDocumentsSection").first ?? ""
        XCTAssertTrue(header.contains("size: 36"))
        XCTAssertTrue(header.contains(".title2.bold()"))
        XCTAssertTrue(header.contains("lineLimit(1)"))
        XCTAssertFalse(header.contains(".largeTitle"))
        XCTAssertFalse(header.contains("size: 48"))
    }

    func testPrimaryActionsHaveEqualProminenceAndSharedIdentifiers() throws {
        let source = try contentViewSource()
        XCTAssertTrue(source.contains("homePrimaryActions"))
        XCTAssertTrue(source.contains("primaryActionButton"))
        XCTAssertTrue(source.contains("scanDocumentButton"))
        XCTAssertTrue(source.contains("importPhotosButton"))
        XCTAssertTrue(source.contains("openPDFButton"))
        XCTAssertTrue(source.contains("createDocumentButton"))
        // Equal prominence: shared borderedProminent helper, no single-dominant CTA.
        let actions = source.components(separatedBy: "private var acquisitionActions").last?
            .components(separatedBy: "private func primaryActionButton").first ?? ""
        XCTAssertTrue(actions.contains("HomeScreenCopy.scanToPDF"))
        XCTAssertTrue(actions.contains("HomeScreenCopy.photoToPDF"))
        XCTAssertTrue(actions.contains("HomeScreenCopy.openDocument"))
        XCTAssertTrue(actions.contains("HomeScreenCopy.createDocument"))
    }

    func testHomeRecentUsesCompactRowsAndPreviewLimit() throws {
        let source = try contentViewSource()
        XCTAssertTrue(source.contains("style: .compact"))
        XCTAssertEqual(RecentDocumentsStore.homePreviewLimit, 5)
        XCTAssertTrue(source.contains("recentDocumentsMoreButton"))
    }
}
