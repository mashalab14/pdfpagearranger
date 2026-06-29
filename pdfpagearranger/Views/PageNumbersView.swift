import SwiftUI

struct PageNumbersView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: PDFEditorViewModel

    @State private var position: PageNumberPosition
    @State private var format: PageNumberFormat
    @State private var startNumber: Int
    @State private var appliesToAllPages: Bool
    @State private var rangeStart: Int
    @State private var rangeEnd: Int

    init(viewModel: PDFEditorViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        let settings = viewModel.pageNumberSettings
        _position = State(initialValue: settings.position)
        _format = State(initialValue: settings.format)
        _startNumber = State(initialValue: settings.startNumber)
        _appliesToAllPages = State(initialValue: settings.appliesToAllPages)
        _rangeStart = State(initialValue: settings.rangeStart)
        _rangeEnd = State(initialValue: settings.rangeEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    Picker("Position", selection: $position) {
                        ForEach(PageNumberPosition.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(PageNumberFormat.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Start Number") {
                    Stepper(value: $startNumber, in: 1...9_999) {
                        Text("\(startNumber)")
                    }
                    .accessibilityIdentifier("pageNumbersStartNumberStepper")
                }

                Section("Apply To") {
                    Picker("Apply To", selection: $appliesToAllPages) {
                        Text("All pages").tag(true)
                        Text("Selected range").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if !appliesToAllPages {
                        Stepper(value: $rangeStart, in: 1...viewModel.pageCount) {
                            Text("From page \(rangeStart)")
                        }
                        .accessibilityIdentifier("pageNumbersRangeStartStepper")

                        Stepper(value: $rangeEnd, in: 1...viewModel.pageCount) {
                            Text("To page \(rangeEnd)")
                        }
                        .accessibilityIdentifier("pageNumbersRangeEndStepper")
                    }
                }

                if let previewText {
                    Section("Preview") {
                        Text(previewText)
                            .font(.title3.monospaced())
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }

                Section {
                    Button("Apply Page Numbers") {
                        applyPageNumbers()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("applyPageNumbersButton")

                    if viewModel.pageNumberSettings.isEnabled {
                        Button("Remove Page Numbers", role: .destructive) {
                            viewModel.removePageNumbers()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("removePageNumbersButton")
                    }
                }
            }
            .navigationTitle("Page Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("pageNumbersView")
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

    private var previewText: String? {
        guard viewModel.pageCount > 0 else { return nil }
        let settings = draftSettings
        let exportIndex = min(max(viewModel.pageCount - 1, 0), viewModel.pageCount - 1)
        guard settings.shouldApply(toExportIndex: exportIndex) else {
            return "No number on this page"
        }
        let number = settings.displayNumber(forExportIndex: exportIndex)
        return settings.format.formattedText(number: number, totalPages: viewModel.pageCount)
    }

    private var draftSettings: PageNumberSettings {
        PageNumberSettings(
            isEnabled: true,
            position: position,
            format: format,
            startNumber: startNumber,
            appliesToAllPages: appliesToAllPages,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            fontSize: PageNumberSettings.default.fontSize,
            opacity: PageNumberSettings.default.opacity
        )
    }

    private func applyPageNumbers() {
        viewModel.applyPageNumbers(draftSettings)
        dismiss()
    }
}
