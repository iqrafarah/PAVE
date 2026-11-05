import SwiftUI

/// A small tinted button with an icon and a short label, like Kluis, Plan and Profiel.
struct PaveChip: View {
    let icon: ImageResource
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 43)
            .background(Color.surfaceTint, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
