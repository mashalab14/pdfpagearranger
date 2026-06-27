import SwiftUI

@main
struct pdfpagearrangerApp: App {
    @State private var viewModel = PDFEditorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
