import XCTest
@testable import pdfpagearranger

final class DocumentActionsMenuRegressionTests: XCTestCase {
    func testDocumentActionsMenuDefinesImplementedActions() {
        XCTAssertEqual(
            DocumentAction.implementedActions,
            [.compress, .export]
        )
    }

    func testEditorViewUsesDocumentActionsMenuInsteadOfStandaloneDocumentButtons() throws {
        let editorSource = try TestSourceLoader.source(named: "EditorView.swift")

        XCTAssertTrue(editorSource.contains("DocumentActionsMenu"))
        XCTAssertFalse(editorSource.contains("Button(\"Compress\")"))
        XCTAssertFalse(editorSource.contains("Button(\"Export\")"))
    }

    func testDocumentActionsMenuIsFutureReadyForAdditionalActions() throws {
        let menuSource = try TestSourceLoader.source(named: "DocumentActionsMenu.swift")

        XCTAssertTrue(menuSource.contains("enum DocumentAction"))
        XCTAssertTrue(menuSource.contains("static var implementedActions"))
        XCTAssertTrue(menuSource.contains("case compress"))
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
