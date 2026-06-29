import PDFKit
import SwiftUI

struct PageThumbnailView: View {
    let item: PageItem
    let pageNumber: Int
    let document: PDFDocument
    let overlays: [PageObject]
    let overlayImages: [UUID: UIImage]
    let overlayRevision: Int
    let onRotate: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                thumbnailPreview
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    }
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("pageThumbnail_\(pageNumber)")
                    .onTapGesture {
                        onTap()
                    }

                Text("\(pageNumber)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
                    .accessibilityIdentifier("pageNumberLabel_\(pageNumber)")
            }

            HStack(spacing: 0) {
                pageActionButton(icon: "rotate.right", label: "Rotate", action: onRotate)
                pageActionButton(icon: "plus.square.on.square", label: "Duplicate", action: onDuplicate)
                pageActionButton(icon: "trash", label: "Delete", action: onDelete, role: .destructive)
            }
        }
        .task(id: taskKey) {
            await loadThumbnail()
        }
    }

    private var taskKey: String {
        "\(item.id.uuidString)-\(item.rotation)-\(overlayRevision)"
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFit()
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var thumbnailPreview: some View {
        let layout = thumbnailLayout

        Group {
            switch layout.orientation {
            case .portraitStyle:
                thumbnailContent
                    .aspectRatio(layout.aspectRatio, contentMode: .fit)
                    .frame(height: PageThumbnailLayout.standardPortraitHeight)
            case .landscapeStyle:
                thumbnailContent
                    .aspectRatio(layout.aspectRatio, contentMode: .fit)
                    .frame(width: PageThumbnailLayout.standardLandscapeWidth)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var thumbnailLayout: (orientation: PageThumbnailOrientation, aspectRatio: CGFloat) {
        guard let page = document.page(at: item.originalPageIndex) else {
            return (.portraitStyle, 0.72)
        }

        let bounds = page.bounds(for: .mediaBox)
        return (
            PageThumbnailLayout.orientation(for: item.rotation),
            PageThumbnailLayout.displayAspectRatio(
                pageWidth: bounds.width,
                pageHeight: bounds.height,
                rotation: item.rotation
            )
        )
    }

    private func pageActionButton(
        icon: String,
        label: String,
        action: @escaping () -> Void,
        role: ButtonRole? = nil
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("\(label.lowercased())Page_\(pageNumber)")
    }

    private func loadThumbnail() async {
        thumbnail = await ThumbnailService.shared.thumbnail(
            for: item,
            document: document,
            overlays: overlays,
            overlayImages: overlayImages,
            revision: overlayRevision
        )
    }
}
