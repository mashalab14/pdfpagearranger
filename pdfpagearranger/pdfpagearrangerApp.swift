import SwiftUI

@main
struct pdfpagearrangerApp: App {
    @State private var viewModel = PDFEditorViewModel()
    @AppStorage(AppAppearanceSettings.storageKey)
    private var appearanceModeRaw = AppAppearanceMode.defaultMode.rawValue

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .defaultMode
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
