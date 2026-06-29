import SwiftUI
import XCTest
@testable import pdfpagearranger

final class AppAppearanceSettingsRegressionTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppAppearanceSettingsRegressionTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        AppAppearanceSettings.clearStoredMode(in: defaults)
    }

    override func tearDown() {
        AppAppearanceSettings.clearStoredMode(in: defaults)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultAppearanceModeIsDevice() {
        XCTAssertEqual(AppAppearanceMode.defaultMode, .device)
        XCTAssertEqual(AppAppearanceSettings.storedMode(in: defaults), .device)
        XCTAssertNil(defaults.string(forKey: AppAppearanceSettings.storageKey))
    }

    func testSelectingLightPersists() {
        AppAppearanceSettings.setStoredMode(.light, in: defaults)

        XCTAssertEqual(defaults.string(forKey: AppAppearanceSettings.storageKey), AppAppearanceMode.light.rawValue)
        XCTAssertEqual(AppAppearanceSettings.storedMode(in: defaults), .light)
        XCTAssertEqual(AppAppearanceMode(rawValue: defaults.string(forKey: AppAppearanceSettings.storageKey) ?? "")?.colorScheme, .light)
    }

    func testSelectingDarkPersists() {
        AppAppearanceSettings.setStoredMode(.dark, in: defaults)

        XCTAssertEqual(defaults.string(forKey: AppAppearanceSettings.storageKey), AppAppearanceMode.dark.rawValue)
        XCTAssertEqual(AppAppearanceSettings.storedMode(in: defaults), .dark)
        XCTAssertEqual(AppAppearanceMode(rawValue: defaults.string(forKey: AppAppearanceSettings.storageKey) ?? "")?.colorScheme, .dark)
    }

    func testSelectingDevicePersists() {
        AppAppearanceSettings.setStoredMode(.light, in: defaults)
        AppAppearanceSettings.setStoredMode(.device, in: defaults)

        XCTAssertEqual(defaults.string(forKey: AppAppearanceSettings.storageKey), AppAppearanceMode.device.rawValue)
        XCTAssertEqual(AppAppearanceSettings.storedMode(in: defaults), .device)
        XCTAssertNil(AppAppearanceMode(rawValue: defaults.string(forKey: AppAppearanceSettings.storageKey) ?? "")?.colorScheme)
    }

    func testInvalidStoredValueFallsBackToDevice() {
        defaults.set("invalid-mode", forKey: AppAppearanceSettings.storageKey)

        XCTAssertEqual(AppAppearanceSettings.storedMode(in: defaults), .device)
    }

    func testAppRootAppliesPreferredColorScheme() throws {
        let appSource = try TestSourceLoader.source(named: "pdfpagearrangerApp.swift", subdirectory: nil)
        XCTAssertTrue(appSource.contains("preferredColorScheme"))
        XCTAssertTrue(appSource.contains("AppAppearanceSettings.storageKey"))
    }

    func testContentViewExposesSettingsEntryPoint() throws {
        let source = try TestSourceLoader.source(named: "ContentView.swift", subdirectory: nil)
        XCTAssertTrue(source.contains("gearshape"))
        XCTAssertTrue(source.contains("settingsButton"))
        XCTAssertTrue(source.contains("SettingsView"))
    }

    func testSettingsViewDefinesAppearancePicker() throws {
        let source = try TestSourceLoader.source(named: "SettingsView.swift", subdirectory: "Views")
        XCTAssertTrue(source.contains("Settings"))
        XCTAssertTrue(source.contains("Appearance"))
        XCTAssertTrue(source.contains("AppAppearanceMode"))
        XCTAssertTrue(source.contains("appearanceModePicker"))
    }
}

private enum TestSourceLoader {
    static func source(named fileName: String, subdirectory: String?) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var sourceURL = projectRoot.appendingPathComponent("pdfpagearranger")
        if let subdirectory {
            sourceURL.appendPathComponent(subdirectory)
        }
        sourceURL.appendPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
