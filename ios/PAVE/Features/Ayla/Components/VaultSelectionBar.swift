import SwiftUI

/// Shown in place of the text field while choosing vault items: how many are chosen, and "Verder".
struct VaultSelectionBar: View {
    let count: Int
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image(.iconFolder)
                .accessibilityHidden(true)
            Text(count == 1 ? "1 item geselecteerd" : "\(count) items geselecteerd")
                .textStyle(.chip)
                .foregroundStyle(Color.ink)
                .padding(.leading, 8)
            Spacer(minLength: 12)
            Button(action: onContinue) {
                Text("Verder")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.canvas)
                    .frame(width: 101, height: 35)
                    .background(Color.brandGreen, in: .capsule)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.5 : 1)
        }
        .padding(.leading, 26)
        .padding(.trailing, 16)
        .frame(height: 69.3)
        .background(Color.surfaceTint, in: .capsule)
    }
}

#Preview {
    VaultSelectionBar(count: 2) {}
        .padding(.leading, 21)
        .padding(.trailing, 22)
}
