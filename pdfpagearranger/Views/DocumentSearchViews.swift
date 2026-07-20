import SwiftUI

struct DocumentSearchSheet: View {
    @Bindable var viewModel: PDFEditorViewModel
    let onSelectMatch: (DocumentSearchMatch) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                resultsContent
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.closeDocumentSearch()
                        dismiss()
                    }
                    .accessibilityIdentifier("documentSearchCloseButton")
                }
            }
            .onAppear {
                viewModel.openDocumentSearch()
                isSearchFieldFocused = true
            }
        }
        .accessibilityIdentifier("documentSearchSheet")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search document", text: searchQueryBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .accessibilityIdentifier("documentSearchField")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var resultsContent: some View {
        if viewModel.documentSearch.results.isEmptyQuery {
            emptyPrompt
        } else if !viewModel.documentSearch.results.hasMatches {
            noResultsView
        } else {
            resultsList
        }
    }

    private var emptyPrompt: some View {
        ContentUnavailableView(
            "Search Document",
            systemImage: "magnifyingglass",
            description: Text("Type to find text anywhere in this PDF.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "text.magnifyingglass",
            description: Text("No matches found for “\(trimmedQuery)”.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("documentSearchNoResults")
    }

    private var resultsList: some View {
        List {
            ForEach(viewModel.documentSearch.results.groupedByPage(), id: \.pageItemID) { group in
                Section("Page \(group.pageNumber)") {
                    ForEach(group.matches) { match in
                        Button {
                            viewModel.selectDocumentSearchMatch(at: match.globalIndex)
                            onSelectMatch(match)
                        } label: {
                            DocumentSearchResultRow(match: match, query: trimmedQuery)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("documentSearchResult_\(match.globalIndex)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("documentSearchResultsList")
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { viewModel.documentSearch.results.query },
            set: { viewModel.updateDocumentSearchQuery($0) }
        )
    }

    private var trimmedQuery: String {
        viewModel.documentSearch.results.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DocumentSearchResultRow: View {
    let match: DocumentSearchMatch
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(highlightedSnippet)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var highlightedSnippet: AttributedString {
        var attributed = AttributedString(match.contextSnippet)
        guard let range = attributed.range(
            of: match.matchedText,
            options: .caseInsensitive
        ) else {
            return attributed
        }
        attributed[range].font = .body.bold()
        attributed[range].foregroundColor = .orange
        return attributed
    }
}

struct PageModeSearchBar: View {
    @Bindable var viewModel: PDFEditorViewModel
    let onClose: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search document", text: searchQueryBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .accessibilityIdentifier("pageModeSearchField")

                Button("Close", action: onClose)
                    .font(.subheadline)
                    .accessibilityIdentifier("pageModeSearchCloseButton")
            }

            HStack {
                Button {
                    _ = viewModel.moveToPreviousDocumentSearchMatch()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!viewModel.documentSearch.results.hasMatches)
                .accessibilityLabel("Previous match")
                .accessibilityIdentifier("pageModeSearchPreviousMatch")

                Button {
                    _ = viewModel.moveToNextDocumentSearchMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!viewModel.documentSearch.results.hasMatches)
                .accessibilityLabel("Next match")
                .accessibilityIdentifier("pageModeSearchNextMatch")

                Spacer()

                if let positionLabel = viewModel.documentSearch.positionLabel {
                    Text(positionLabel)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("pageModeSearchPositionLabel")
                } else if !viewModel.documentSearch.results.isEmptyQuery {
                    Text("No results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("pageModeSearchNoResults")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pageModeSearchBar")
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { viewModel.documentSearch.results.query },
            set: { viewModel.updateDocumentSearchQuery($0) }
        )
    }
}

struct SearchHighlightCanvasLayer: UIViewRepresentable {
    let matches: [DocumentSearchMatch]
    let activeMatchID: UUID?
    let pageRotation: Int
    let pageSize: CGSize

    func makeUIView(context: Context) -> SearchHighlightDrawingUIView {
        let view = SearchHighlightDrawingUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SearchHighlightDrawingUIView, context: Context) {
        uiView.matches = matches
        uiView.activeMatchID = activeMatchID
        uiView.pageRotation = pageRotation
        uiView.pageSize = pageSize
        uiView.setNeedsDisplay()
    }
}

final class SearchHighlightDrawingUIView: UIView {
    var matches: [DocumentSearchMatch] = []
    var activeMatchID: UUID?
    var pageRotation: Int = 0
    var pageSize: CGSize = .zero

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              pageSize.width > 0,
              pageSize.height > 0,
              !matches.isEmpty else {
            return
        }

        SearchHighlightRenderer.drawHighlights(
            matches: matches,
            activeMatchID: activeMatchID,
            pageRotation: pageRotation,
            renderSize: pageSize,
            in: context,
            coordinateSpace: .topLeftOrigin
        )
    }
}
