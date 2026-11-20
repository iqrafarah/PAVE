import SwiftUI
import UIKit

extension AngularGradient {
    /// The colour wheel on the button for a colour of your own.
    static let colorWheel = AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)
}

/// The iPhone's own colour picker; every change shows at once in the app.
struct OwnColorPicker: UIViewControllerRepresentable {
    let initial: UInt32
    let title: String
    let onChange: (UInt32) -> Void
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = UIColor(hex: initial)
        picker.supportsAlpha = false
        picker.title = title
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let onChange: (UInt32) -> Void
        let onFinish: () -> Void

        init(onChange: @escaping (UInt32) -> Void, onFinish: @escaping () -> Void) {
            self.onChange = onChange
            self.onFinish = onFinish
        }

        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            onChange(color.srgbValue)
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            onFinish()
        }
    }
}

extension UIColor {
    /// The colour as 0xRRGGBB in sRGB; colours outside sRGB are clipped to it.
    var srgbValue: UInt32 {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap { cgColor.converted(to: $0, intent: .defaultIntent, options: nil) }
        let components = srgb?.components ?? [0, 0, 0]
        func channel(_ index: Int) -> UInt32 {
            let value = components.count > index ? components[index] : components.first ?? 0
            return UInt32((min(max(value, 0), 1) * 255).rounded())
        }
        return channel(0) << 16 | channel(1) << 8 | channel(2)
    }
}
