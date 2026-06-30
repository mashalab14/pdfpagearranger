import SwiftUI

struct WatermarkView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: PDFEditorViewModel

    @State private var text: String
    @State private var opacity: Double
    @State private var normalizedScale: Double
    @State private var color: WatermarkColor
    @State private var rotationDegrees: Double
    @State private var position: WatermarkPosition
    @State private var applyScope: WatermarkApplyScope
    @State private var currentPageIndex: Int
    @State private var rangeStart: Int
    @State private var rangeEnd: Int

    init(viewModel: PDFEditorViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        let settings = viewModel.watermarkSettings
        _text = State(initialValue: settings.text)
        _opacity = State(initialValue: Double(settings.opacity))
        _normalizedScale = State(initialValue: Double(settings.normalizedScale))
        _color = State(initialValue: settings.color)
        _rotationDegrees = State(initialValue: Double(settings.rotationDegrees))
        _position = State(initialValue: settings.position)
        _applyScope = State(initialValue: settings.applyScope)
        _currentPageIndex = State(initialValue: settings.currentPageIndex)
        _rangeStart = State(initialValue: settings.rangeStart)
        _rangeEnd = State(initialValue: settings.rangeEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Watermark text", text: $text)
                        .textInputAutocapitalization(.characters)
                        .accessibilityIdentifier("watermarkTextField")
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

                    Picker("Color", selection: $color) {
                        ForEach(WatermarkColor.presets, id: \.self) { preset in
                            Text(colorTitle(for: preset)).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("watermarkColorPicker")

                    Picker("Position", selection: $position) {
                        ForEach(WatermarkPosition.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
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
                    .disabled(trimmedText.isEmpty)
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
        guard !trimmedText.isEmpty else { return nil }
        return trimmedText
    }

    private var draftSettings: WatermarkSettings {
        WatermarkSettings(
            isEnabled: true,
            text: trimmedText,
            opacity: CGFloat(opacity),
            normalizedScale: CGFloat(normalizedScale),
            color: color,
            rotationDegrees: CGFloat(rotationDegrees),
            position: position,
            applyScope: applyScope,
            currentPageIndex: currentPageIndex,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    private func applyWatermark() {
        viewModel.applyWatermark(draftSettings)
        dismiss()
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
