import SwiftUI
import UIKit

struct PlacedSignatureEditPopover: View {
    let overlay: PageObject
    let anchorPoint: CGPoint
    let onSelectPresetColor: (SignatureInkColor) -> Void
    let onSelectCustomColor: (UIColor) -> Void
    let onDecreaseThickness: () -> Void
    let onIncreaseThickness: () -> Void

    @State private var showColorPicker = false
    @State private var pickerColor: UIColor

    init(
        overlay: PageObject,
        anchorPoint: CGPoint,
        onSelectPresetColor: @escaping (SignatureInkColor) -> Void,
        onSelectCustomColor: @escaping (UIColor) -> Void,
        onDecreaseThickness: @escaping () -> Void,
        onIncreaseThickness: @escaping () -> Void
    ) {
        self.overlay = overlay
        self.anchorPoint = anchorPoint
        self.onSelectPresetColor = onSelectPresetColor
        self.onSelectCustomColor = onSelectCustomColor
        self.onDecreaseThickness = onDecreaseThickness
        self.onIncreaseThickness = onIncreaseThickness
        _pickerColor = State(initialValue: overlay.effectiveSignatureInkUIColor)
    }

    private var strokeWidthPoints: Int {
        overlay.effectiveSignatureStrokeWidthPoints
    }

    private var usesCustomColor: Bool {
        overlay.signatureCustomInkRGBA != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(SignatureInkColor.presetDisplayOrder) { color in
                    presetColorButton(color)
                }
            }

            HStack(spacing: 6) {
                Button {
                    pickerColor = overlay.effectiveSignatureInkUIColor
                    showColorPicker = true
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(usesCustomColor ? Color.accentColor : Color.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .strokeBorder(
                                    usesCustomColor ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .accessibilityLabel("Advanced Color")
                .accessibilityIdentifier("signatureEditAdvancedColorButton")

                Button(action: onDecreaseThickness) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .disabled(PlacedSignatureStrokeWidth.decreased(from: strokeWidthPoints) == nil)
                .accessibilityLabel("Decrease Thickness")
                .accessibilityIdentifier("signatureEditThicknessMinus")

                Text(PlacedSignatureStrokeWidth.label(for: strokeWidthPoints))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40)
                    .accessibilityIdentifier("signatureEditThicknessValue")

                Button(action: onIncreaseThickness) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .disabled(PlacedSignatureStrokeWidth.increased(from: strokeWidthPoints) == nil)
                .accessibilityLabel("Increase Thickness")
                .accessibilityIdentifier("signatureEditThicknessPlus")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
        .position(anchorPoint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("placedSignatureEditPopover")
        .sheet(isPresented: $showColorPicker) {
            SignatureUIColorPicker(color: $pickerColor) { selected in
                onSelectCustomColor(selected)
            }
        }
        .onChange(of: overlay.effectiveSignatureInkUIColor) { _, newValue in
            pickerColor = newValue
        }
    }

    private func presetColorButton(_ color: SignatureInkColor) -> some View {
        let isSelected = !usesCustomColor && overlay.effectiveSignatureInkColor == color

        return Button {
            onSelectPresetColor(color)
        } label: {
            Circle()
                .fill(color.displayColor)
                .frame(width: 22, height: 22)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.markupTitle)
        .accessibilityIdentifier(color.accessibilityIdentifier)
    }
}
