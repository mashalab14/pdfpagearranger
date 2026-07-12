import SwiftUI

struct ScanDraftPageAdjustmentView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    let pageID: UUID

    @State private var sourceImage: UIImage?
    @State private var imageLoadFailed = false
    @State private var previewContainerSize: CGSize = .zero

    private let imageLoader = ScanDraftPreviewImageLoader()

    var body: some View {
        VStack(spacing: 0) {
            previewArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel(accessibilityPageContext)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Rotate") {
                    sessionViewModel.rotateAdjustmentGeometryClockwise()
                }
                .accessibilityLabel("Rotate clockwise")

                if showsRedetectAction {
                    Button("Redetect") {
                        Task { await sessionViewModel.redetectDocumentEdges() }
                    }
                    .disabled(sessionViewModel.isDetectingEdges || sessionViewModel.isApplyingGeometry)
                    .accessibilityLabel("Redetect document")
                } else {
                    Button("Reset") {
                        sessionViewModel.resetAdjustmentGeometry()
                    }
                    .disabled(sessionViewModel.isDetectingEdges || sessionViewModel.isApplyingGeometry)
                    .accessibilityLabel("Reset corners")
                }
            }
        }
        .overlay {
            if sessionViewModel.isApplyingGeometry || sessionViewModel.isDetectingEdges {
                processingOverlay
            }
        }
        .alert(
            "Adjust Page Error",
            isPresented: Binding(
                get: { sessionViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        sessionViewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                sessionViewModel.errorMessage = nil
            }
        } message: {
            Text(sessionViewModel.errorMessage ?? "")
        }
        .task(id: pageID) {
            await loadSourceImage()
        }
    }

    private var navigationTitle: String {
        if let session = sessionViewModel.adjustmentSession {
            return "Adjust Page \(session.pageNumber)"
        }
        return "Adjust Page"
    }

    private var accessibilityPageContext: String {
        if let session = sessionViewModel.adjustmentSession {
            return "Adjust page \(session.pageNumber) of \(session.totalPages)"
        }
        return "Adjust page"
    }

    private var showsRedetectAction: Bool {
        sessionViewModel.adjustmentSession?.sourceType == .photos
    }

    @ViewBuilder
    private var previewArea: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemBackground)

                if let sourceImage,
                   sessionViewModel.adjustmentSession != nil {
                    let displayRect = ScanPageGeometryEngine.aspectFitDisplayRect(
                        imageSize: sourceImage.size,
                        in: geometry.size
                    )

                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayRect.width, height: displayRect.height)
                        .position(x: displayRect.midX, y: displayRect.midY)

                    ScanDraftCornerOverlayView(
                        geometry: Binding(
                            get: { sessionViewModel.adjustmentSession?.workingGeometry ?? .default },
                            set: { sessionViewModel.updateAdjustmentWorkingGeometry($0) }
                        ),
                        displayRect: displayRect,
                        imageSize: sourceImage.size
                    )
                } else if imageLoadFailed {
                    ContentUnavailableView(
                        "Preview Unavailable",
                        systemImage: "photo",
                        description: Text("This page could not be loaded.")
                    )
                } else {
                    ProgressView("Loading page…")
                }
            }
            .onAppear {
                previewContainerSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                previewContainerSize = newSize
            }
        }
        .padding(16)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                sessionViewModel.cancelPageAdjustment()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(sessionViewModel.isApplyingGeometry)
            .accessibilityLabel("Cancel")

            Button("Apply") {
                Task {
                    _ = await sessionViewModel.applyPageAdjustment()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(sessionViewModel.isApplyingGeometry || sessionViewModel.adjustmentSession == nil)
            .accessibilityLabel("Apply")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            ProgressView(sessionViewModel.isApplyingGeometry ? "Applying correction…" : "Detecting document…")
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func loadSourceImage() async {
        guard let page = sessionViewModel.document?.pages.first(where: { $0.id == pageID }),
              let sessionDirectory = sessionViewModel.sessionDirectory else {
            imageLoadFailed = true
            return
        }

        sourceImage = nil
        imageLoadFailed = false

        do {
            let image = try await imageLoader.loadImage(
                reference: page.originalImage,
                sessionDirectory: sessionDirectory,
                maxPixelDimension: 1_600
            )
            sourceImage = image
        } catch {
            imageLoadFailed = true
        }
    }
}

struct ScanDraftCornerOverlayView: View {
    @Binding var geometry: ScanPageGeometry
    let displayRect: CGRect
    let imageSize: CGSize

    @State private var activeCornerIndex: Int?

    private var corners: [ScanNormalizedPoint] {
        geometry.effectiveCorners ?? ScanPageGeometryEngine.fullBoundsCorners()
    }

    var body: some View {
        ZStack {
            boundaryPath
                .stroke(Color.accentColor, lineWidth: 2)

            ForEach(Array(corners.enumerated()), id: \.offset) { index, corner in
                cornerHandle(at: index, corner: corner)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var boundaryPath: Path {
        var path = Path()
        let points = corners.map {
            ScanPageGeometryEngine.normalizedToPreview($0, displayRect: displayRect, imageSize: imageSize)
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func cornerHandle(at index: Int, corner: ScanNormalizedPoint) -> some View {
        let center = ScanPageGeometryEngine.normalizedToPreview(
            corner,
            displayRect: displayRect,
            imageSize: imageSize
        )

        return Circle()
            .fill(Color.accentColor)
            .frame(width: 16, height: 16)
            .overlay {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .position(center)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        activeCornerIndex = index
                        updateCorner(at: index, to: value.location)
                    }
                    .onEnded { _ in
                        activeCornerIndex = nil
                    }
            )
            .accessibilityLabel(cornerAccessibilityLabel(for: index))
            .accessibilityHint("Drag to adjust this corner.")
            .accessibilityAdjustableAction { direction in
                nudgeCorner(at: index, direction: direction)
            }
    }

    private func updateCorner(at index: Int, to location: CGPoint) {
        var updatedCorners = corners
        guard updatedCorners.indices.contains(index) else { return }

        let normalized = ScanPageGeometryEngine.previewToNormalized(
            location,
            displayRect: displayRect,
            imageSize: imageSize
        )
        updatedCorners[index] = ScanNormalizedPoint(
            x: min(max(normalized.x, 0), 1),
            y: min(max(normalized.y, 0), 1)
        )

        if case .success(let validated) = ScanPageGeometryEngine.validateCorners(updatedCorners) {
            var updatedGeometry = geometry
            updatedGeometry.userAdjustedCorners = validated
            updatedGeometry.perspectiveCorrectionEnabled = true
            geometry = updatedGeometry
        }
    }

    private func nudgeCorner(at index: Int, direction: AccessibilityAdjustmentDirection) {
        var updatedCorners = corners
        guard updatedCorners.indices.contains(index) else { return }

        let delta: CGFloat = 0.01
        var corner = updatedCorners[index]
        switch direction {
        case .increment:
            corner.x = min(corner.x + delta, 1)
            corner.y = min(corner.y + delta, 1)
        case .decrement:
            corner.x = max(corner.x - delta, 0)
            corner.y = max(corner.y - delta, 0)
        @unknown default:
            break
        }
        updatedCorners[index] = corner

        if case .success(let validated) = ScanPageGeometryEngine.validateCorners(updatedCorners) {
            var updatedGeometry = geometry
            updatedGeometry.userAdjustedCorners = validated
            updatedGeometry.perspectiveCorrectionEnabled = true
            geometry = updatedGeometry
        }
    }

    private func cornerAccessibilityLabel(for index: Int) -> String {
        switch index {
        case 0: return "Top-left corner"
        case 1: return "Top-right corner"
        case 2: return "Bottom-right corner"
        case 3: return "Bottom-left corner"
        default: return "Corner"
        }
    }
}
