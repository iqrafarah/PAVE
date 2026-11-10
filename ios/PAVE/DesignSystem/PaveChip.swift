import SwiftUI

/// A small tinted button with an icon and a short label, like Kluis, Plan and Profiel.
struct PaveChip: View {
    let icon: ImageResource
    let title: String
    /// Figma gives each chip a fixed width; without it the chip is as wide as its content.
    var width: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(icon)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
            }
            .padding(.leading, 19)
            .padding(.trailing, 18)
            .frame(minWidth: width, minHeight: 43, alignment: .leading)
            .background(Color.surfaceTint, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
    }
}

#Preview {
    HStack(spacing: 15) {
        PaveChip(icon: .iconFolder, title: "Kluis") {}
        PaveChip(icon: .iconMap, title: "Plan") {}
        PaveChip(icon: .iconPerson, title: "Profiel") {}
    }
    .padding()
    .background(Color.canvas)
}
