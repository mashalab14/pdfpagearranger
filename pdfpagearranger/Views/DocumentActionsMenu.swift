import SwiftUI

enum DocumentAction: String, CaseIterable, Identifiable {
    case compress
    case export

    // Future document-level actions:
    // renameDocument, documentInformation, passwordProtect, watermark,
    // pageNumbers, splitDocument, mergeDocuments, duplicateDocument

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compress:
            return "Compress"
        case .export:
            return "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .compress:
            return "arrow.down.doc"
        case .export:
            return "square.and.arrow.up"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .compress:
            return "compressButton"
        case .export:
            return "documentActionExport"
        }
    }

    /// Actions currently exposed in the Document Actions menu.
    static var implementedActions: [DocumentAction] {
        [.compress, .export]
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
