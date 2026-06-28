import XCTest

class PDFPagesUITestCase: XCTestCase {
    var app: XCUIApplication!
    private var tempPDFURLs: [URL] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = []
    }

    override func tearDownWithError() throws {
        for url in tempPDFURLs {
            try? FileManager.default.removeItem(at: url)
        }
        tempPDFURLs.removeAll()
        app = nil
    }

    @discardableResult
    func launchWithImportedPDF(pageCount: Int = 4, seedOverlay: Bool = false) throws -> URL {
        app.launchArguments = ["-uiTestAutoImportPages", String(pageCount)]
        if seedOverlay {
            app.launchArguments.append("-uiTestSeedOverlay")
        }
        app.launch()

        let documentReady = app.descendants(matching: .any)["documentModeReady"]
        XCTAssertTrue(documentReady.waitForExistence(timeout: 20), "Document Mode should open after import")

        let firstThumbnail = app.descendants(matching: .any)["pageThumbnail_1"]
        XCTAssertTrue(firstThumbnail.waitForExistence(timeout: 20), "First page thumbnail should render after import")
        return URL(fileURLWithPath: "/UITest/AutoImport-\(pageCount).pdf")
    }

    func waitForThumbnail(pageNumber: Int, timeout: TimeInterval = 15) -> XCUIElement {
        let thumbnail = app.descendants(matching: .any)["pageThumbnail_\(pageNumber)"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: timeout), "Thumbnail \(pageNumber) should appear")
        return thumbnail
    }

    var documentActionsButton: XCUIElement {
        app.buttons["documentActionsButton"]
    }

    func openDocumentActionsMenu(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            documentActionsButton.waitForExistence(timeout: 5),
            "Document Actions menu button should appear in Document Mode",
            file: file,
            line: line
        )
        XCTAssertTrue(
            documentActionsButton.isEnabled,
            "Document Actions menu button should be enabled when a document is open",
            file: file,
            line: line
        )
        documentActionsButton.tap()
    }

    func documentActionButton(named title: String) -> XCUIElement {
        app.buttons[title]
    }

    func tapDocumentAction(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        openDocumentActionsMenu(file: file, line: line)

        let actionButton = documentActionButton(named: title)
        XCTAssertTrue(
            actionButton.waitForExistence(timeout: 3),
            "Expected \(title) in the Document Actions menu",
            file: file,
            line: line
        )
        actionButton.tap()
    }

    func assertExportShareSheetIsPresented(
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let shareSheet = app.descendants(matching: .any)["exportShareSheet"]
        XCTAssertTrue(
            shareSheet.waitForExistence(timeout: timeout),
            "Export should present the share sheet",
            file: file,
            line: line
        )
    }

    func dismissExportShareSheetIfPresent() {
        if app.descendants(matching: .any)["exportShareSheet"].exists {
            app.swipeDown(velocity: .fast)
        }
    }
}
