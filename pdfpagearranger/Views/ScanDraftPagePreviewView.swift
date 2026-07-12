import SwiftUI

struct ScanDraftPagePreviewView: View {
    let page: ScanDraftPage
    let pageNumber: Int
    let totalPages: Int
    let sessionDirectory: URL
    let imageLoader: any ScanDraftPreviewImageLoading
    let reloadToken: String

    @State private var previewImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)

            Group {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                } else if isLoading {
                    ProgressView("Loading page…")
                } else if loadFailed {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("This page could not be previewed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await loadPreview() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    ProgressView("Loading page…")
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(pageNumber) of \(totalPages)")
        .accessibilityAddTraits(.isImage)
        .task(id: taskKey) {
            await loadPreview()
        }
    }

    private var taskKey: String {
        "\(page.id.uuidString)-\(reloadToken)-\(page.processingFingerprint ?? page.originalImage.relativePath)"
    }

    private func loadPreview() async {
        let activePageID = page.id
        isLoading = true
        loadFailed = false
        previewImage = nil

        let reference = imageLoader.previewReference(for: page)
        let cacheKey = imageLoader.cacheKey(
            for: page,
            reference: reference,
            purpose: .mainPreview
        )

        if let loader = imageLoader as? ScanDraftPreviewImageLoader,
           let cached = await loader.cachedImage(for: cacheKey) {
            guard !Task.isCancelled else { return }
            previewImage = cached
            isLoading = false
            return
        }

        do {
            let image = try await imageLoader.loadImage(
                reference: reference,
                sessionDirectory: sessionDirectory,
                maxPixelDimension: ScanDraftPreviewImageLoader.mainPreviewMaxPixelDimension
            )
            guard ScanDraftPreviewLoadGuard.shouldApplyLoadedImage(
                requestedPageID: activePageID,
                currentPageID: page.id,
                isCancelled: Task.isCancelled
            ) else { return }
            previewImage = image
            if let loader = imageLoader as? ScanDraftPreviewImageLoader {
                await loader.storeCachedImage(image, for: cacheKey)
            }
            loadFailed = false
        } catch {
            guard ScanDraftPreviewLoadGuard.shouldApplyLoadedImage(
                requestedPageID: activePageID,
                currentPageID: page.id,
                isCancelled: Task.isCancelled
            ) else { return }
            previewImage = nil
            loadFailed = true
        }

        isLoading = false
    }
}
