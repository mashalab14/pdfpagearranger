import XCTest

final class RecentDocumentsUITests: PDFPagesUITestCase {
    func testCreateDocumentAppearsInHomeRecentAndReopens() throws {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))

        let createButton = app.buttons["createDocumentButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_1"].waitForExistence(timeout: 15))

        let newPDFButton = app.buttons["newPDFButton"]
        XCTAssertTrue(newPDFButton.waitForExistence(timeout: 5))
        newPDFButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 10))
        // Home rows combine accessibility children, so prefer stable section/list identifiers
        // plus the row's combined label ("Untitled, …") rather than homeRecentDocument-N.
        XCTAssertTrue(
            app.buttons["recentDocumentsMoreButton"].waitForExistence(timeout: 10),
            "Created document should appear in Recent (More visible)"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["recentDocumentsHomeList"].waitForExistence(timeout: 5),
            "Home Recent list should render after Create Document"
        )
        XCTAssertFalse(app.descendants(matching: .any)["recentDocumentsEmptyLabel"].exists)

        let homeRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Untitled")
        ).firstMatch
        XCTAssertTrue(homeRow.waitForExistence(timeout: 5), "Home Recent row should expose Untitled label")
        homeRow.tap()

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["pageThumbnail_1"].waitForExistence(timeout: 15))
    }

    func testRecentMoreListOpensAndSelectsDocument() throws {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))

        app.buttons["createDocumentButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 15))
        app.buttons["newPDFButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 10))

        // Second document so More remains meaningful with a populated list.
        app.buttons["createDocumentButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 15))
        app.buttons["newPDFButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 10))

        let moreButton = app.buttons["recentDocumentsMoreButton"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        moreButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["recentDocumentsListView"].waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "recentDocumentRow-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 15))
    }
}

final class ExportPaywallUITests: PDFPagesUITestCase {
    func testExportOverFreeLimitPresentsPaywall() throws {
        try launchWithImportedPDF(pageCount: 21)
        waitForThumbnail(pageNumber: 1)

        tapDocumentAction("Export")

        XCTAssertTrue(
            app.staticTexts["Unlock PDF Pages Pro"].waitForExistence(timeout: 8),
            "Export over free limit should present paywall"
        )
        XCTAssertTrue(app.buttons["Continue for now"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["exportShareSheet"].exists)
    }

    func testContinueForNowAllowsExportShareSheet() throws {
        try launchWithImportedPDF(pageCount: 21)
        waitForThumbnail(pageNumber: 1)

        tapDocumentAction("Export")
        XCTAssertTrue(app.staticTexts["Unlock PDF Pages Pro"].waitForExistence(timeout: 8))
        app.buttons["Continue for now"].tap()
        assertExportShareSheetIsPresented()
    }
}

final class DocumentSearchUITests: PDFPagesUITestCase {
    func testDocumentModeSearchButtonOpensSearchSheet() throws {
        try launchWithImportedPDF(pageCount: 2)
        waitForThumbnail(pageNumber: 1)

        let searchButton = app.buttons["documentModeSearchButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["documentSearchSheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["documentSearchField"].exists)

        app.buttons["documentSearchCloseButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].waitForExistence(timeout: 5))
    }
}

final class PageAnnotationUITests: PDFPagesUITestCase {
    func testPageModeAddSheetExposesAnnotationOptions() throws {
        try launchWithImportedPDF(pageCount: 1)
        waitForThumbnail(pageNumber: 1)

        app.descendants(matching: .any)["pageThumbnail_1"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].waitForExistence(timeout: 10))

        app.buttons["pageModeAddButton"].tap()
        XCTAssertTrue(app.buttons["addDrawOption"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addStickyNoteOption"].exists)

        app.buttons["addDrawOption"].tap()
        // Drawing mode guidance / chrome should appear without crashing.
        XCTAssertTrue(app.descendants(matching: .any)["pageModeView"].exists)
    }
}
