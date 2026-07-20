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
    enum Style {
        case standard
        case compact
    }

    let record: RecentDocumentRecord
    let thumbnail: UIImage?
    var style: Style = .standard

    private var thumbnailSize: CGSize {
        switch style {
        case .standard: CGSize(width: 44, height: 58)
        case .compact: CGSize(width: 32, height: 42)
        }
    }

    private var titleFont: Font {
        switch style {
        case .standard: .body.weight(.medium)
        case .compact: .subheadline.weight(.medium)
        }
    }

    private var dateFont: Font {
        switch style {
        case .standard: .subheadline
        case .compact: .caption
        }
    }

    private var rowSpacing: CGFloat {
        switch style {
        case .standard: 12
        case .compact: 10
        }
    }

    var body: some View {
        HStack(spacing: rowSpacing) {
            thumbnailView
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: style == .compact ? 2 : 4) {
                Text(record.displayName)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(Self.formattedDate(record.lastOpenedAt))
                    .font(dateFont)
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
