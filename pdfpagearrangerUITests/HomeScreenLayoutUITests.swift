import XCTest

/// Home layout: action-first acquisition funnel with compact recent preview.
final class HomeScreenLayoutUITests: PDFPagesUITestCase {
    func testAllFourPrimaryActionsAreVisibleOnInitialLoad() {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))

        let actions = app.descendants(matching: .any)["homePrimaryActions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))

        let scan = app.buttons["scanDocumentButton"]
        let photo = app.buttons["importPhotosButton"]
        let openPDF = app.buttons["openPDFButton"]
        let create = app.buttons["createDocumentButton"]

        XCTAssertTrue(scan.exists)
        XCTAssertTrue(photo.exists)
        XCTAssertTrue(openPDF.exists)
        XCTAssertTrue(create.exists)

        XCTAssertTrue(scan.isHittable)
        XCTAssertTrue(photo.isHittable)
        XCTAssertTrue(openPDF.isHittable)
        XCTAssertTrue(create.isHittable)
    }

    func testHomeRecentDocumentsPreviewAndMoreRemainAvailable() {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))

        for _ in 0..<2 {
            let create = app.buttons["createDocumentButton"]
            XCTAssertTrue(create.waitForExistence(timeout: 5))
            create.tap()
            waitForUnifiedEditorReady(timeout: 20)
            let newPDF = app.buttons["newPDFButton"]
            XCTAssertTrue(newPDF.waitForExistence(timeout: 5))
            newPDF.tap()
            XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 10))
        }

        XCTAssertTrue(app.descendants(matching: .any)["recentDocumentsHomeList"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recentDocumentsMoreButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["recentDocumentsEmptyLabel"].exists)
        // Preview clamp (≤5) is covered by HomeScreenLayoutRegressionTests / store tests.
        XCTAssertFalse(app.descendants(matching: .any)["homeRecentDocument-5"].exists)
    }

    func testCreatePDFNavigationStillOpensEditor() {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))
        let create = app.buttons["createDocumentButton"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        waitForUnifiedEditorReady(timeout: 20)
        XCTAssertTrue(app.descendants(matching: .any)["documentModeReady"].exists)
    }

    func testOpenPDFButtonRemainsAvailableForImportNavigation() {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))
        let openPDF = app.buttons["openPDFButton"]
        XCTAssertTrue(openPDF.waitForExistence(timeout: 5))
        XCTAssertTrue(openPDF.isHittable)
    }

    func testScanAndPhotoPrimaryActionsRemainWired() {
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scanDocumentButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["importPhotosButton"].exists)
        XCTAssertTrue(app.buttons["scanDocumentButton"].isHittable)
        XCTAssertTrue(app.buttons["importPhotosButton"].isHittable)
    }
}
