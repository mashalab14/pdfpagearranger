import XCTest

final class SettingsRegressionUITests: PDFPagesUITestCase {
    func testSettingsOpensFromEmptyStateAndShowsAppearanceOptions() throws {
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["emptyStateView"].waitForExistence(timeout: 5))

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settingsView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["appearanceModePicker"].exists)
        XCTAssertTrue(app.buttons["Device"].exists)
        XCTAssertTrue(app.buttons["Light"].exists)
        XCTAssertTrue(app.buttons["Dark"].exists)
    }

    func testSettingsOpensFromDocumentMode() throws {
        try launchWithImportedPDF(pageCount: 1)

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settingsView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
    }
}
