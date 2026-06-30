import SwiftUI
import UIKit

struct SignatureUIColorPicker: UIViewControllerRepresentable {
    @Binding var color: UIColor
    let onColorChanged: (UIColor) -> Void

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = color
        picker.supportsAlpha = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {
        if uiViewController.selectedColor != color {
            uiViewController.selectedColor = color
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(color: $color, onColorChanged: onColorChanged)
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        @Binding var color: UIColor
        let onColorChanged: (UIColor) -> Void

        init(color: Binding<UIColor>, onColorChanged: @escaping (UIColor) -> Void) {
            _color = color
            self.onColorChanged = onColorChanged
        }

        func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
            let selected = viewController.selectedColor
            color = selected
            onColorChanged(selected)
        }
    }
}
