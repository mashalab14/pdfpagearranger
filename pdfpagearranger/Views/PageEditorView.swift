import PDFKit
import SwiftUI

struct PageEditorRoute: Hashable {
    let pageItemID: UUID
}

struct PageEditorView: View {
    let pageItem: PageItem
    let pageNumber: Int
    let document: PDFDocument

    @Environment(\.dismiss) private var dismiss
    @State private var pageImage: UIImage?
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            addButtonBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Page \(pageNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PageAddOptionsSheet()
        }
        .task(id: renderTaskKey) {
            await loadPageImage()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if let pageImage {
            ZoomablePageView(image: pageImage)
                .padding()
        } else {
            ProgressView("Loading page…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var addButtonBar: some View {
        HStack {
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var renderTaskKey: String {
        "\(pageItem.id.uuidString)-\(pageItem.rotation)"
    }

    private func loadPageImage() async {
        pageImage = await PageRenderService.shared.pageImage(for: pageItem, document: document)
    }
}

#Preview {
    NavigationStack {
        PageEditorView(
            pageItem: PageItem(originalPageIndex: 0),
            pageNumber: 1,
            document: PDFDocument()
        )
    }
}
