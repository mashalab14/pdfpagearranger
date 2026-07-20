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
    func launchWithImportedPDF(
        pageCount: Int = 4,
        seedOverlay: Bool = false,
        isolatedSignatureLibrary: Bool = false
    ) throws -> URL {
        app.launchArguments = ["-uiTestAutoImportPages", String(pageCount)]
        if seedOverlay {
            app.launchArguments.append("-uiTestSeedOverlay")
        }
        if isolatedSignatureLibrary {
            app.launchArguments.append("-uiTestIsolatedSignatureLibrary")
        }
        app.launch()

        waitForUnifiedEditorReady()
        return URL(fileURLWithPath: "/UITest/AutoImport-\(pageCount).pdf")
    }

    /// Import / create / reopen readiness: unified vertical editor is loaded (not the Pages organizer grid).
    func waitForUnifiedEditorReady(timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        let documentReady = app.descendants(matching: .any)["documentModeReady"]
        XCTAssertTrue(
            documentReady.waitForExistence(timeout: timeout),
            "Unified document editor should open after import",
            file: file,
            line: line
        )

        let scroll = app.descendants(matching: .any)["unifiedDocumentScroll"]
        XCTAssertTrue(
            scroll.waitForExistence(timeout: timeout),
            "Unified document scroll surface should be present",
            file: file,
            line: line
        )

        let pageMode = app.descendants(matching: .any)["pageModeView"]
        XCTAssertTrue(
            pageMode.waitForExistence(timeout: timeout),
            "Active page editor surface should be present",
            file: file,
            line: line
        )

        let firstSlot = app.descendants(matching: .any)["documentPageSlot_1"]
        XCTAssertTrue(
            firstSlot.waitForExistence(timeout: timeout),
            "First page slot should render in the unified document",
            file: file,
            line: line
        )

        let addButton = app.buttons["pageModeAddButton"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: timeout),
            "Page Add control should be available on the active page toolbar",
            file: file,
            line: line
        )
    }

    var unifiedDocumentScroll: XCUIElement {
        app.descendants(matching: .any)["unifiedDocumentScroll"]
    }

    var pageModeView: XCUIElement {
        app.descendants(matching: .any)["pageModeView"]
    }

    func selectSeededImageOverlay(file: StaticString = #filePath, line: UInt = #line) {
        let overlay = app.descendants(matching: .any)["imageOverlay"]
        XCTAssertTrue(
            overlay.waitForExistence(timeout: 10),
            "Seeded image overlay should be present on the active page",
            file: file,
            line: line
        )
        overlay.tap()
        let resizeHandle = app.otherElements["overlayResizeHandle"]
        XCTAssertTrue(
            resizeHandle.waitForExistence(timeout: 5),
            "Selecting the seeded overlay should reveal the resize handle",
            file: file,
            line: line
        )
    }

    func documentPageSlot(_ pageNumber: Int) -> XCUIElement {
        app.descendants(matching: .any)["documentPageSlot_\(pageNumber)"]
    }

    /// Performs a vertical drag on the unified document scroll surface.
    func dragUnifiedDocument(fromNormalizedY startY: CGFloat, toNormalizedY endY: CGFloat) {
        let start = unifiedDocumentScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = unifiedDocumentScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func assertActivePage(pageNumber: Int, of total: Int, file: StaticString = #filePath, line: UInt = #line) {
        let expected = "page \(pageNumber) of \(total)"
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: pageModeView)
        let result = XCTWaiter.wait(for: [expectation], timeout: 8)
        XCTAssertEqual(
            result,
            .completed,
            "Expected active page accessibility value '\(expected)', got '\(pageModeView.value as? String ?? "nil")'",
            file: file,
            line: line
        )
    }

    /// Ensures the first page is active after import (scroll activation can briefly prefer a neighbour).
    func ensureFirstPageActive(of total: Int, file: StaticString = #filePath, line: UInt = #line) {
        if (pageModeView.value as? String) == "page 1 of \(total)" {
            return
        }

        // Prefer scrolling back to the top before using the organizer.
        for _ in 0..<4 {
            if (pageModeView.value as? String) == "page 1 of \(total)" {
                return
            }
            unifiedDocumentScroll.swipeDown()
        }

        if (pageModeView.value as? String) != "page 1 of \(total)" {
            activatePageViaOrganizer(1, file: file, line: line)
        }
        assertActivePage(pageNumber: 1, of: total, file: file, line: line)
    }

    /// Opens the Pages organizer sheet (⋯ → Pages). Thumbnails live only here.
    func openPagesOrganizer(file: StaticString = #filePath, line: UInt = #line) {
        // Dismiss any leftover menu presentation before opening.
        if app.buttons["Pages"].exists == false {
            openDocumentActionsMenu(file: file, line: line)
        } else {
            openDocumentActionsMenu(file: file, line: line)
        }

        let pagesAction = documentActionButton(named: "Pages")
        if !pagesAction.waitForExistence(timeout: 2) {
            // Menu may have failed to present; retry once.
            openDocumentActionsMenu(file: file, line: line)
        }
        XCTAssertTrue(
            pagesAction.waitForExistence(timeout: 3),
            "Expected Pages in the Document Actions menu",
            file: file,
            line: line
        )
        pagesAction.tap()

        let organizer = app.descendants(matching: .any)["documentPagesOrganizer"]
        let grid = app.descendants(matching: .any)["documentPageGrid"]
        XCTAssertTrue(
            organizer.waitForExistence(timeout: 5) || grid.waitForExistence(timeout: 5),
            "Pages organizer should present the document page grid",
            file: file,
            line: line
        )
    }

    func dismissPagesOrganizer(file: StaticString = #filePath, line: UInt = #line) {
        let done = app.buttons["documentPagesOrganizerDone"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
        } else {
            app.navigationBars.buttons["Done"].tap()
        }
        XCTAssertTrue(
            unifiedDocumentScroll.waitForExistence(timeout: 5),
            "Dismissing Pages organizer should return to the unified document surface",
            file: file,
            line: line
        )
    }

    /// Activates a page via the Pages organizer (reliable for non-adjacent jumps).
    func activatePageViaOrganizer(_ pageNumber: Int, file: StaticString = #filePath, line: UInt = #line) {
        openPagesOrganizer(file: file, line: line)
        let thumbnail = waitForThumbnail(pageNumber: pageNumber, file: file, line: line)
        thumbnail.tap()
        XCTAssertTrue(
            unifiedDocumentScroll.waitForExistence(timeout: 5),
            "Selecting a page in the organizer should return to the unified document",
            file: file,
            line: line
        )
    }

    @discardableResult
    func waitForThumbnail(
        pageNumber: Int,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let thumbnail = app.descendants(matching: .any)["pageThumbnail_\(pageNumber)"]
        XCTAssertTrue(
            thumbnail.waitForExistence(timeout: timeout),
            "Thumbnail \(pageNumber) should appear in the Pages organizer",
            file: file,
            line: line
        )
        return thumbnail
    }

    var documentActionsButton: XCUIElement {
        app.buttons["documentActionsButton"]
    }

    func openDocumentActionsMenu(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            documentActionsButton.waitForExistence(timeout: 5),
            "Document Actions menu button should appear in the unified editor",
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
