import SwiftUI

/// Summarises the selected vault items and offers to continue.
struct VaultSelectionBar: View {
    let count: Int
    /// Shown instead of the count for a moment, such as when the maximum is reached.
    var note: String?
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image(.iconFolder)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconHeight(18)
                .foregroundStyle(Color.paveAccent)
                .accessibilityHidden(true)
            Text(note ?? (count == 1 ? "1 item geselecteerd" : "\(count) items geselecteerd"))
                .textStyle(.chip)
                .foregroundStyle(note == nil ? Color.ink : Color.warning)
                .contentTransition(.opacity)
                .padding(.leading, 8)
            Spacer(minLength: 12)
            Button(action: onContinue) {
                Text("Verder")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.canvas)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    // Figma's 101 × 35 at the standard text size; larger text makes it grow instead of cutting off.
                    .frame(minWidth: 101, minHeight: 35)
                    .background(Color.paveAccentFill, in: .capsule)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pave)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
        }
        .padding(.leading, 26)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
        .frame(minHeight: 69.3)
        .background(Color.paveSurfaceTint, in: .capsule)
    }
}

#Preview {
    VaultSelectionBar(count: 2) {}
        .padding(.leading, 21)
        .padding(.trailing, 22)
}
