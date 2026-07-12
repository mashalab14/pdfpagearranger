import SwiftUI

struct ScanDraftPageAdjustmentView: View {
    @Bindable var sessionViewModel: ScanDraftSessionViewModel
    let pageID: UUID

    @State private var sourceImage: UIImage?
    @State private var imageLoadFailed = false

    private let imageLoader = ScanDraftPreviewImageLoader()

    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
                .padding(.horizontal, 16)
                .padding(.top, 12)

            previewArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if sessionViewModel.adjustmentSection == .appearance {
                visualControls
            }

            bottomBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel(accessibilityPageContext)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if sessionViewModel.adjustmentSection == .crop {
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
                } else {
                    Button("Reset Visual") {
                        sessionViewModel.resetAdjustmentVisualAdjustments()
                    }
                    .disabled(sessionViewModel.isApplyingGeometry)
                    .accessibilityLabel("Reset visual adjustments")
                }
            }
        }
        .overlay {
            if sessionViewModel.isApplyingGeometry
                || sessionViewModel.isDetectingEdges
                || sessionViewModel.isGeneratingVisualPreview {
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
        .onChange(of: sessionViewModel.adjustmentSection) { _, newSection in
            if newSection == .appearance {
                sessionViewModel.scheduleVisualPreviewUpdate()
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Adjustment Section", selection: $sessionViewModel.adjustmentSection) {
            ForEach(ScanPageAdjustmentSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Adjustment section")
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

                if sessionViewModel.adjustmentSection == .appearance,
                   let previewImage = sessionViewModel.visualPreviewImage {
                    fittedImage(previewImage, in: geometry.size)
                } else if let sourceImage,
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
        }
        .padding(16)
    }

    @ViewBuilder
    private var visualControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modeSelector
                brightnessControl
                contrastControl
                if showsSaturationControl {
                    saturationControl
                }
                if showsThresholdControl {
                    thresholdControl
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: 280)
        .background(.bar)
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mode")
                .font(.subheadline.weight(.semibold))

            Picker("Visual Mode", selection: modeBinding) {
                ForEach(ScanVisualMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Visual mode")
        }
    }

    private var brightnessControl: some View {
        adjustmentSlider(
            title: "Brightness",
            value: brightnessBinding,
            range: ScanVisualAdjustments.minimumAdjustmentValue...ScanVisualAdjustments.maximumAdjustmentValue,
            accessibilityFormat: "Brightness"
        )
    }

    private var contrastControl: some View {
        adjustmentSlider(
            title: "Contrast",
            value: contrastBinding,
            range: ScanVisualAdjustments.minimumAdjustmentValue...ScanVisualAdjustments.maximumAdjustmentValue,
            accessibilityFormat: "Contrast"
        )
    }

    private var saturationControl: some View {
        adjustmentSlider(
            title: "Saturation",
            value: saturationBinding,
            range: -0.5...0.5,
            accessibilityFormat: "Saturation"
        )
    }

    private var thresholdControl: some View {
        adjustmentSlider(
            title: "Threshold",
            value: thresholdBinding,
            range: ScanVisualAdjustments.minimumBlackAndWhiteThreshold...ScanVisualAdjustments.maximumBlackAndWhiteThreshold,
            accessibilityFormat: "Black and white threshold"
        )
    }

    private var showsSaturationControl: Bool {
        workingVisualAdjustments.mode.supportsSaturationControl
    }

    private var showsThresholdControl: Bool {
        workingVisualAdjustments.mode.supportsThresholdControl
    }

    private var workingVisualAdjustments: ScanVisualAdjustments {
        sessionViewModel.adjustmentSession?.workingVisualAdjustments ?? .neutral
    }

    private var modeBinding: Binding<ScanVisualMode> {
        Binding(
            get: { workingVisualAdjustments.mode },
            set: { newMode in
                var adjustments = workingVisualAdjustments
                adjustments.mode = newMode
                if !newMode.supportsSaturationControl {
                    adjustments.saturation = nil
                }
                if newMode.supportsThresholdControl, adjustments.blackAndWhiteThreshold == nil {
                    adjustments.blackAndWhiteThreshold = ScanVisualAdjustments.defaultBlackAndWhiteThreshold
                }
                sessionViewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)
            }
        )
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { Double(workingVisualAdjustments.brightness) },
            set: { value in
                var adjustments = workingVisualAdjustments
                adjustments.brightness = CGFloat(value)
                sessionViewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)
            }
        )
    }

    private var contrastBinding: Binding<Double> {
        Binding(
            get: { Double(workingVisualAdjustments.contrast) },
            set: { value in
                var adjustments = workingVisualAdjustments
                adjustments.contrast = CGFloat(value)
                sessionViewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)
            }
        )
    }

    private var saturationBinding: Binding<Double> {
        Binding(
            get: { Double(workingVisualAdjustments.saturation ?? 0) },
            set: { value in
                var adjustments = workingVisualAdjustments
                adjustments.saturation = CGFloat(value)
                sessionViewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)
            }
        )
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { Double(workingVisualAdjustments.resolvedBlackAndWhiteThreshold) },
            set: { value in
                var adjustments = workingVisualAdjustments
                adjustments.blackAndWhiteThreshold = CGFloat(value)
                sessionViewModel.updateAdjustmentWorkingVisualAdjustments(adjustments)
            }
        )
    }

    private func adjustmentSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        accessibilityFormat: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
                .accessibilityLabel(accessibilityFormat)
                .accessibilityValue(Text(String(format: "%.2f", value.wrappedValue)))
        }
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
            ProgressView(processingMessage)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(processingMessage)
    }

    private var processingMessage: String {
        if sessionViewModel.isApplyingGeometry {
            return "Applying changes…"
        }
        if sessionViewModel.isDetectingEdges {
            return "Detecting document…"
        }
        return "Updating preview…"
    }

    private func fittedImage(_ image: UIImage, in containerSize: CGSize) -> some View {
        let displayRect = ScanPageGeometryEngine.aspectFitDisplayRect(
            imageSize: image.size,
            in: containerSize
        )

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: displayRect.width, height: displayRect.height)
            .position(x: displayRect.midX, y: displayRect.midY)
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
            sessionViewModel.scheduleVisualPreviewUpdate()
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
