import Foundation

enum UITestLaunchConfiguration {
    static let importPDFArgument = "-uiTestImportPDF"
    static let seedOverlayArgument = "-uiTestSeedOverlay"
    static let autoImportPagesArgument = "-uiTestAutoImportPages"
    static let autoImportPagesEnvironmentKey = "UI_TEST_AUTO_IMPORT_PAGES"
    static let isolatedSignatureLibraryArgument = "-uiTestIsolatedSignatureLibrary"
    static let documentReadyIdentifier = "documentModeReady"

    private static var cachedIsolatedSignatureLibraryRoot: URL?

    static var isolatedSignatureLibraryRoot: URL? {
        guard ProcessInfo.processInfo.arguments.contains(isolatedSignatureLibraryArgument) else {
            return nil
        }
        if let cachedIsolatedSignatureLibraryRoot {
            return cachedIsolatedSignatureLibraryRoot
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UITestSignatureLibrary-\(UUID().uuidString)", isDirectory: true)
        cachedIsolatedSignatureLibraryRoot = url
        return url
    }

    static var importPDFPath: String? {
        launchValue(for: importPDFArgument)
            ?? ProcessInfo.processInfo.environment[importPDFArgument]
    }

    static var autoImportPageCount: Int? {
        if let value = launchValue(for: autoImportPagesArgument) ?? ProcessInfo.processInfo.environment[autoImportPagesEnvironmentKey] {
            return Int(value)
        }
        return nil
    }

    static var shouldSeedOverlay: Bool {
        ProcessInfo.processInfo.arguments.contains(seedOverlayArgument)
    }

    private static func launchValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
