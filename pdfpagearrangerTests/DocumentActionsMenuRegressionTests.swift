import XCTest
@testable import pdfpagearranger

final class DocumentActionsMenuRegressionTests: XCTestCase {
    func testDocumentActionsMenuDefinesImplementedActions() {
        XCTAssertEqual(
            DocumentAction.implementedActions,
            [.compress, .pageNumbers, .watermark, .organizePages, .export]
        )
    }

    func testEditorViewUsesDocumentActionsMenuInsteadOfStandaloneDocumentButtons() throws {
        let editorSource = try TestSourceLoader.source(named: "EditorView.swift")

        XCTAssertTrue(editorSource.contains("DocumentActionsMenu") || editorSource.contains("onDocumentAction"))
        XCTAssertTrue(editorSource.contains("showWatermark"))
        XCTAssertTrue(editorSource.contains("showPagesOrganizer"))
        XCTAssertTrue(editorSource.contains("isUnifiedDocumentSurface"))
        XCTAssertFalse(editorSource.contains("Button(\"Compress\")"))
        XCTAssertFalse(editorSource.contains("Button(\"Export\")"))
        XCTAssertFalse(editorSource.contains("navigationDestination(item:"))
    }

    func testDocumentActionsMenuIsFutureReadyForAdditionalActions() throws {
        let menuSource = try TestSourceLoader.source(named: "DocumentActionsMenu.swift")

        XCTAssertTrue(menuSource.contains("enum DocumentAction"))
        XCTAssertTrue(menuSource.contains("static var implementedActions"))
        XCTAssertTrue(menuSource.contains("case compress"))
        XCTAssertTrue(menuSource.contains("case pageNumbers"))
        XCTAssertTrue(menuSource.contains("case watermark"))
        XCTAssertTrue(menuSource.contains("case organizePages"))
        XCTAssertTrue(menuSource.contains("case export"))
    }
}

private enum TestSourceLoader {
    static func source(named fileName: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("pdfpagearranger")
            .appendingPathComponent("Views")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
