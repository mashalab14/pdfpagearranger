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

    private var thickness: SignatureInkThickness {
        overlay.effectiveSignatureStrokeThickness
    }

    private var usesCustomColor: Bool {
        overlay.signatureCustomInkRGBA != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SignatureInkColor.presetDisplayOrder) { color in
                presetColorButton(color)
            }

            divider

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
            .accessibilityLabel("Advanced Color")
            .accessibilityIdentifier("signatureEditAdvancedColorButton")

            divider

            Button(action: onDecreaseThickness) {
                Image(systemName: "minus")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(thickness.steppedDown() == nil)
            .accessibilityLabel("Decrease Thickness")
            .accessibilityIdentifier("signatureEditThicknessMinus")

            Text(thickness.pointsLabel)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 36)
                .accessibilityIdentifier("signatureEditThicknessValue")

            Button(action: onIncreaseThickness) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(thickness.steppedUp() == nil)
            .accessibilityLabel("Increase Thickness")
            .accessibilityIdentifier("signatureEditThicknessPlus")
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 24)
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
