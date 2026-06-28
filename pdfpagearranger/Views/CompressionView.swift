import SwiftUI

struct CompressionView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: PDFEditorViewModel

    @State private var selectedPreset: CompressionPreset = .default
    @State private var preparedInput: CompressionPreparedInput?
    @State private var compressionResult: CompressionResult?
    @State private var isPreparing = true
    @State private var isCompressing = false
    @State private var compressionProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let compressionResult {
                    resultView(compressionResult)
                } else {
                    configurationView
                }
            }
            .navigationTitle("Compress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        cleanupTemporaryFiles()
                        dismiss()
                    }
                    .disabled(isCompressing)
                }
            }
            .task {
                await prepareInput()
            }
            .sheet(isPresented: $showShareSheet, onDismiss: cleanupShareFile) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .alert("Compression Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isCompressing)
        .accessibilityIdentifier("compressionView")
    }

    private var configurationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sizeSummaryCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("Compression Preset")
                        .font(.headline)

                    ForEach(CompressionPreset.allCases) { preset in
                        presetRow(preset)
                    }
                }

                if isCompressing {
                    VStack(spacing: 8) {
                        ProgressView(value: compressionProgress)
                        Text("Compressing… \(Int(compressionProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Cancel") {
                            Task { await viewModel.cancelCompression() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button {
                        Task { await runCompression() }
                    } label: {
                        Text("Compress PDF")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPreparing || preparedInput == nil)
                    .accessibilityIdentifier("compressPDFButton")
                }
            }
            .padding()
        }
    }

    private var sizeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current File Size")
                .font(.headline)

            if isPreparing {
                ProgressView("Preparing export preview…")
            } else if let preparedInput {
                Text(ByteCountFormatter.string(fromByteCount: preparedInput.byteCount, countStyle: .file))
                    .font(.title2.bold())

                if let estimate = selectedPreset.estimatedCompressedSize(from: preparedInput.byteCount) {
                    Text("Estimated: \(ByteCountFormatter.string(fromByteCount: estimate, countStyle: .file))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Could not prepare the current document for compression.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func presetRow(_ preset: CompressionPreset) -> some View {
        Button {
            selectedPreset = preset
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedPreset == preset ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(.tint)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.title)
                            .foregroundStyle(.primary)
                            .font(.body.weight(.semibold))
                        if preset == .default {
                            Text("Default")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(preset.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPreset == preset ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("compressionPreset_\(preset.rawValue)")
    }

    private func resultView(_ result: CompressionResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text(ByteCountFormatter.string(fromByteCount: result.originalByteCount, countStyle: .file))
                    .font(.title3)
                Image(systemName: "arrow.down")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: result.compressedByteCount, countStyle: .file))
                    .font(.largeTitle.bold())
                Text("\(Int(result.percentSaved.rounded()))% smaller")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .accessibilityIdentifier("compressionResultSummary")

            VStack(spacing: 12) {
                Button("Save / Share") {
                    shareURL = result.outputURL
                    showShareSheet = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("compressionShareButton")

                Button("Continue Editing") {
                    Task {
                        await viewModel.adoptCompressedPDF(from: result.outputURL)
                        cleanupTemporaryFiles(keepingResult: false)
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("compressionContinueEditingButton")
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    @MainActor
    private func prepareInput() async {
        isPreparing = true
        defer { isPreparing = false }

        do {
            preparedInput = try await viewModel.prepareCompressionInput()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func runCompression() async {
        guard let preparedInput else { return }

        isCompressing = true
        compressionProgress = 0
        defer { isCompressing = false }

        do {
            compressionResult = try await viewModel.compressPreparedPDF(
                preparedInput,
                settings: CompressionSettings(preset: selectedPreset)
            ) { progress in
                Task { @MainActor in
                    compressionProgress = progress
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanupTemporaryFiles(keepingResult: Bool = true) {
        if let preparedInput {
            try? FileManager.default.removeItem(at: preparedInput.exportURL)
        }
        if !keepingResult, let compressionResult {
            try? FileManager.default.removeItem(at: compressionResult.outputURL)
        }
        if !keepingResult {
            self.compressionResult = nil
        }
        preparedInput = nil
    }

    private func cleanupShareFile() {
        shareURL = nil
    }
}

private extension CompressionPreset {
    func estimatedCompressedSize(from originalBytes: Int64) -> Int64? {
        estimatedCompressedBytes(from: originalBytes)
    }
}
