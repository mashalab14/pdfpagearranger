import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct WatermarkView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: PDFEditorViewModel

    @State private var watermarkType: WatermarkType
    @State private var text: String
    @State private var draftImage: UIImage?
    @State private var opacity: Double
    @State private var normalizedScale: Double
    @State private var color: WatermarkColor
    @State private var rotationDegrees: Double
    @State private var position: WatermarkPosition
    @State private var layer: WatermarkLayer
    @State private var applyScope: WatermarkApplyScope
    @State private var currentPageIndex: Int
    @State private var rangeStart: Int
    @State private var rangeEnd: Int
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    init(viewModel: PDFEditorViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        let settings = viewModel.watermarkSettings
        _watermarkType = State(initialValue: settings.watermarkType)
        _text = State(initialValue: settings.text)
        _draftImage = State(initialValue: viewModel.watermarkImage)
        _opacity = State(initialValue: Double(settings.opacity))
        _normalizedScale = State(initialValue: Double(settings.normalizedScale))
        _color = State(initialValue: settings.color)
        _rotationDegrees = State(initialValue: Double(settings.rotationDegrees))
        _position = State(initialValue: settings.position)
        _layer = State(initialValue: settings.layer)
        _applyScope = State(initialValue: settings.applyScope)
        _currentPageIndex = State(initialValue: settings.currentPageIndex)
        _rangeStart = State(initialValue: settings.rangeStart)
        _rangeEnd = State(initialValue: settings.rangeEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Watermark Type", selection: $watermarkType) {
                        ForEach(WatermarkType.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("watermarkTypePicker")

                    if watermarkType == .text {
                        TextField("Watermark text", text: $text)
                            .textInputAutocapitalization(.characters)
                            .accessibilityIdentifier("watermarkTextField")
                    } else {
                        if let draftImage {
                            Image(uiImage: draftImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 160)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("watermarkImagePreview")
                        }

                        Button("Choose Image") {
                            showPhotosPicker = true
                        }
                        .accessibilityIdentifier("chooseWatermarkImageButton")

                        Button("Choose from Files") {
                            showFileImporter = true
                        }
                        .accessibilityIdentifier("chooseWatermarkFileButton")

                        if draftImage != nil {
                            Button("Replace Image") {
                                showPhotosPicker = true
                            }
                            .accessibilityIdentifier("replaceWatermarkImageButton")

                            Button("Remove Image", role: .destructive) {
                                draftImage = nil
                            }
                            .accessibilityIdentifier("removeWatermarkImageButton")
                        }
                    }
                }

                Section("Appearance") {
                    Slider(value: $opacity, in: 0.1...1.0) {
                        Text("Opacity")
                    }
                    .accessibilityIdentifier("watermarkOpacitySlider")

                    Stepper(value: $normalizedScale, in: 0.05...0.80, step: 0.05) {
                        Text("Size: \(Int(normalizedScale * 100))% of page width")
                    }
                    .accessibilityIdentifier("watermarkScaleStepper")

                    Stepper(value: $rotationDegrees, in: -180...180, step: 5) {
                        Text("Rotation: \(Int(rotationDegrees))°")
                    }
                    .accessibilityIdentifier("watermarkRotationStepper")

                    if watermarkType == .text {
                        Picker("Color", selection: $color) {
                            ForEach(WatermarkColor.presets, id: \.self) { preset in
                                Text(colorTitle(for: preset)).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("watermarkColorPicker")
                    }

                    Picker("Position", selection: $position) {
                        ForEach(WatermarkPosition.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Picker("Layer", selection: $layer) {
                        ForEach(WatermarkLayer.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("watermarkLayerPicker")

                    if layer == .behindContent {
                        Text("Behind content may be hidden by page text, images, or filled backgrounds.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("watermarkBehindContentHelper")
                    }
                }

                Section("Apply To") {
                    Picker("Apply To", selection: $applyScope) {
                        ForEach(WatermarkApplyScope.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    if applyScope == .currentPage {
                        Stepper(value: $currentPageIndex, in: 1...max(viewModel.pageCount, 1)) {
                            Text("Page \(currentPageIndex)")
                        }
                        .accessibilityIdentifier("watermarkCurrentPageStepper")
                    }

                    if applyScope == .pageRange {
                        Stepper(value: $rangeStart, in: 1...max(viewModel.pageCount, 1)) {
                            Text("From page \(rangeStart)")
                        }
                        .accessibilityIdentifier("watermarkRangeStartStepper")

                        Stepper(value: $rangeEnd, in: 1...max(viewModel.pageCount, 1)) {
                            Text("To page \(rangeEnd)")
                        }
                        .accessibilityIdentifier("watermarkRangeEndStepper")
                    }
                }

                if let previewText {
                    Section("Preview") {
                        Text(previewText)
                            .font(.title3)
                            .foregroundStyle(Color(uiColor: color.uiColor).opacity(opacity))
                            .rotationEffect(.degrees(rotationDegrees))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }

                Section {
                    Button("Apply Watermark") {
                        applyWatermark()
                    }
                    .disabled(!canApply)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("applyWatermarkButton")

                    if viewModel.watermarkSettings.isEnabled {
                        Button("Remove Watermark", role: .destructive) {
                            viewModel.removeWatermark()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("removeWatermarkButton")
                    }
                }
            }
            .navigationTitle("Watermark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("watermarkView")
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            importFile(result)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await importPhotoItem(newValue)
            }
        }
        .onChange(of: rangeStart) { _, newValue in
            if rangeEnd < newValue {
                rangeEnd = newValue
            }
        }
        .onChange(of: rangeEnd) { _, newValue in
            if rangeStart > newValue {
                rangeStart = newValue
            }
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewText: String? {
        guard watermarkType == .text, !trimmedText.isEmpty else { return nil }
        return trimmedText
    }

    private var canApply: Bool {
        switch watermarkType {
        case .text:
            return !trimmedText.isEmpty
        case .image:
            return draftImage != nil
        }
    }

    private var draftSettings: WatermarkSettings {
        WatermarkSettings(
            isEnabled: true,
            watermarkType: watermarkType,
            text: trimmedText.isEmpty ? WatermarkSettings.default.text : trimmedText,
            imageAssetID: nil,
            opacity: CGFloat(opacity),
            normalizedScale: CGFloat(normalizedScale),
            color: color,
            rotationDegrees: CGFloat(rotationDegrees),
            position: position,
            layer: layer,
            applyScope: applyScope,
            currentPageIndex: currentPageIndex,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    private func applyWatermark() {
        let image = watermarkType == .image ? draftImage : nil
        viewModel.applyWatermark(draftSettings, watermarkImage: image)
        dismiss()
    }

    private func importPhotoItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        draftImage = image
        selectedPhotoItem = nil
    }

    private func importFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first,
              url.startAccessingSecurityScopedResource() else {
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return
        }
        draftImage = image
    }

    private func colorTitle(for color: WatermarkColor) -> String {
        switch color {
        case .defaultGray: return "Gray"
        case .black: return "Black"
        case .blue: return "Blue"
        case .red: return "Red"
        default: return "Custom"
        }
    }
}
