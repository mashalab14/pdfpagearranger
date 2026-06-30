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

    private let tapTarget = ContextualControlMetrics.minimumTapTarget

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

    private var columnUnit: CGFloat {
        ContextualControlMetrics.thicknessRowColumnUnit
    }

    var body: some View {
        VStack(spacing: ContextualControlMetrics.popoverRowSpacing) {
            HStack(spacing: ContextualControlMetrics.popoverColorRowSpacing) {
                ForEach(SignatureInkColor.presetDisplayOrder) { color in
                    presetColorButton(color)
                }
            }

            HStack(spacing: 0) {
                columnSlot(width: columnUnit * ContextualControlMetrics.thicknessRowPaletteColumns) {
                    paletteButton
                }
                columnSlot(width: columnUnit * ContextualControlMetrics.thicknessRowMinusColumns) {
                    thicknessButton(
                        systemName: "minus",
                        accessibilityLabel: "Decrease Thickness",
                        accessibilityIdentifier: "signatureEditThicknessMinus",
                        isEnabled: PlacedSignatureStrokeWidth.decreased(from: strokeWidthPoints) != nil,
                        action: onDecreaseThickness
                    )
                }
                columnSlot(width: columnUnit * ContextualControlMetrics.thicknessRowLabelColumns) {
                    Text(PlacedSignatureStrokeWidth.label(for: strokeWidthPoints))
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("signatureEditThicknessValue")
                }
                columnSlot(width: columnUnit * ContextualControlMetrics.thicknessRowPlusColumns) {
                    thicknessButton(
                        systemName: "plus",
                        accessibilityLabel: "Increase Thickness",
                        accessibilityIdentifier: "signatureEditThicknessPlus",
                        isEnabled: PlacedSignatureStrokeWidth.increased(from: strokeWidthPoints) != nil,
                        action: onIncreaseThickness
                    )
                }
            }
            .frame(width: ContextualControlMetrics.popoverContentWidth)
            .padding(.vertical, ContextualControlMetrics.thicknessRowVerticalInset)
        }
        .contextualControlChrome()
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

    private func columnSlot<Content: View>(
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            content()
        }
        .frame(width: width, height: tapTarget)
    }

    private var paletteButton: some View {
        Button {
            pickerColor = overlay.effectiveSignatureInkUIColor
            showColorPicker = true
        } label: {
            Image(systemName: "paintpalette.fill")
                .font(ContextualControlMetrics.symbolFont.weight(ContextualControlMetrics.symbolWeight))
                .foregroundStyle(usesCustomColor ? Color.accentColor : Color.primary)
                .frame(
                    width: ContextualControlMetrics.presetColorDiameter,
                    height: ContextualControlMetrics.presetColorDiameter
                )
                .background(
                    Circle()
                        .strokeBorder(
                            usesCustomColor ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
                .frame(width: tapTarget, height: tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: tapTarget, height: tapTarget)
        .accessibilityLabel("Advanced Color")
        .accessibilityIdentifier("signatureEditAdvancedColorButton")
    }

    private func thicknessButton(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(ContextualControlMetrics.symbolFont.weight(ContextualControlMetrics.symbolWeight))
                .frame(width: tapTarget, height: tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: tapTarget, height: tapTarget)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func presetColorButton(_ color: SignatureInkColor) -> some View {
        let isSelected = !usesCustomColor && overlay.effectiveSignatureInkColor == color

        return Button {
            onSelectPresetColor(color)
        } label: {
            Circle()
                .fill(color.displayColor)
                .frame(
                    width: ContextualControlMetrics.presetColorDiameter,
                    height: ContextualControlMetrics.presetColorDiameter
                )
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(
                                width: ContextualControlMetrics.selectedColorRingDiameter,
                                height: ContextualControlMetrics.selectedColorRingDiameter
                            )
                    }
                }
                .frame(width: tapTarget, height: tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: tapTarget, height: tapTarget)
        .accessibilityLabel(color.markupTitle)
        .accessibilityIdentifier(color.accessibilityIdentifier)
    }
}
