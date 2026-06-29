import SwiftUI

enum DocumentAction: String, CaseIterable, Identifiable {
    case compress
    case pageNumbers
    case watermark
    case export

    // Future document-level actions:
    // renameDocument, documentInformation, passwordProtect,
    // splitDocument, mergeDocuments, duplicateDocument

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compress:
            return "Compress"
        case .pageNumbers:
            return "Page Numbers"
        case .watermark:
            return "Watermark"
        case .export:
            return "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .compress:
            return "arrow.down.doc"
        case .pageNumbers:
            return "number"
        case .watermark:
            return "drop.degreesign"
        case .export:
            return "square.and.arrow.up"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .compress:
            return "compressButton"
        case .pageNumbers:
            return "pageNumbersButton"
        case .watermark:
            return "watermarkButton"
        case .export:
            return "documentActionExport"
        }
    }

    /// Actions currently exposed in the Document Actions menu.
    static var implementedActions: [DocumentAction] {
        [.compress, .pageNumbers, .watermark, .export]
    }
}

struct DocumentActionsMenu: View {
    let isEnabled: Bool
    let onAction: (DocumentAction) -> Void

    var body: some View {
        Menu {
            ForEach(DocumentAction.implementedActions) { action in
                Button {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .accessibilityIdentifier(action.accessibilityIdentifier)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(!isEnabled)
        .accessibilityLabel("More")
        .accessibilityIdentifier("documentActionsButton")
    }
}
