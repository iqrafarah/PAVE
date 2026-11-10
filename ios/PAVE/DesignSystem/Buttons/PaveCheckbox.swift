import SwiftUI

/// A square checkbox from Figma: green with a white tick when on, a grey outline when off.
struct PaveCheckbox: View {
    let isOn: Bool
    var size: CGFloat = 18

    var body: some View {
        Group {
            if isOn {
                Image(.iconCheckboxChecked)
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.checkboxBorder, lineWidth: size >= 18 ? 1.5 : 1.3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        PaveCheckbox(isOn: true)
        PaveCheckbox(isOn: false)
        PaveCheckbox(isOn: false, size: 15)
    }
    .padding()
}
