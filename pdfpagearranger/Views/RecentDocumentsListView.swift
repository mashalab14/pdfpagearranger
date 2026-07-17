import SwiftUI
import UIKit

/// Full list of recent documents opened from Home → More.
struct RecentDocumentsListView: View {
    @Bindable var viewModel: PDFEditorViewModel
    let onSelect: (RecentDocumentRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var records: [RecentDocumentRecord] = []

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    HomeScreenCopy.recentDocuments,
                    systemImage: "doc.text",
                    description: Text(HomeScreenCopy.recentDocumentsEmpty)
                )
            } else {
                List {
                    ForEach(records) { record in
                        Button {
                            onSelect(record)
                            dismiss()
                        } label: {
                            RecentDocumentRow(record: record, thumbnail: viewModel.loadRecentThumbnail(for: record))
                        }
                        .accessibilityIdentifier("recentDocumentRow-\(record.id.uuidString)")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(HomeScreenCopy.recentDocuments)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            records = viewModel.allRecentDocuments()
        }
        .accessibilityIdentifier("recentDocumentsListView")
    }
}

struct RecentDocumentRow: View {
    let record: RecentDocumentRecord
    let thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 44, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(Self.formattedDate(record.lastOpenedAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.displayName), \(Self.formattedDate(record.lastOpenedAt))")
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.secondarySystemFill)
                Image(systemName: "doc.richtext")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func formattedDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
