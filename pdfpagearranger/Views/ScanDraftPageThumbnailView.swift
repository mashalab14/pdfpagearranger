import SwiftUI

struct ScanDraftPageThumbnailView: View {
    let page: ScanDraftPage
    let pageNumber: Int
    let isSelected: Bool
    let sessionDirectory: URL
    let imageLoader: any ScanDraftPreviewImageLoading
    let onSelect: () -> Void

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                thumbnailContent
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color(.separator),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onSelect)

                Text("\(pageNumber)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
            }

            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            } else {
                Color.clear.frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(pageNumber)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Shows this page in the main preview.")
        .task(id: taskKey) {
            await loadThumbnail()
        }
    }

    private var taskKey: String {
        "\(page.id.uuidString)-\(page.thumbnailState)-\(page.thumbnailImage?.relativePath ?? page.originalImage.relativePath)-\(page.processingFingerprint ?? "")"
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        let layout = thumbnailLayout

        Group {
            if loadFailed {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .modifier(ScanDraftThumbnailFrameModifier(layout: layout))
    }

    private var thumbnailLayout: (orientation: PageThumbnailOrientation, aspectRatio: CGFloat) {
        (
            PageThumbnailLayout.orientation(for: page.geometry.rotation),
            PageThumbnailLayout.displayAspectRatio(
                pageWidth: page.originalPixelSize.width,
                pageHeight: page.originalPixelSize.height,
                rotation: page.geometry.rotation
            )
        )
    }

    private func loadThumbnail() async {
        let activePageID = page.id
        isLoading = true
        loadFailed = false

        let reference = imageLoader.thumbnailReference(for: page)
        let cacheKey = imageLoader.cacheKey(
            for: page,
            reference: reference,
            purpose: .thumbnail
        )

        if let loader = imageLoader as? ScanDraftPreviewImageLoader,
           let cached = await loader.cachedImage(for: cacheKey) {
            guard !Task.isCancelled else { return }
            thumbnailImage = cached
            isLoading = false
            return
        }

        do {
            let image = try await imageLoader.loadImage(
                reference: reference,
                sessionDirectory: sessionDirectory,
                maxPixelDimension: ScanDraftPreviewImageLoader.thumbnailMaxPixelDimension
            )
            guard !Task.isCancelled, activePageID == page.id else { return }
            thumbnailImage = image
            if let loader = imageLoader as? ScanDraftPreviewImageLoader {
                await loader.storeCachedImage(image, for: cacheKey)
            }
            loadFailed = false
        } catch {
            guard !Task.isCancelled, activePageID == page.id else { return }
            thumbnailImage = nil
            loadFailed = true
        }

        isLoading = false
    }
}

private struct ScanDraftThumbnailFrameModifier: ViewModifier {
    let layout: (orientation: PageThumbnailOrientation, aspectRatio: CGFloat)

    func body(content: Content) -> some View {
        switch layout.orientation {
        case .portraitStyle:
            content
                .aspectRatio(layout.aspectRatio, contentMode: .fit)
                .frame(height: 88)
        case .landscapeStyle:
            content
                .aspectRatio(layout.aspectRatio, contentMode: .fit)
                .frame(width: 88)
        }
    }
}
