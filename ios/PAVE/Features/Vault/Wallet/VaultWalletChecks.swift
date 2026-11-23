import SwiftUI

/// The checks a real verifier would do on a credential, ticking off one by one. In the demo they are played, and the
/// heading says so.
struct VaultWalletChecks: View {
    /// How many of the checks are done.
    let done: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(VaultMessages.walletChecksTitle)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            ForEach(VaultWalletModel.Check.allCases, id: \.self) { check in
                let isDone = check.rawValue < done
                HStack(spacing: 8) {
                    Image(isDone ? .iconCheckBadgeSolid : .iconClockSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(16)
                        .foregroundStyle(isDone ? Color.paveAccent : Color.inkMuted)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    Text(check.title)
                        .textStyle(.caption)
                        .foregroundStyle(isDone ? Color.ink : Color.inkMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? "klaar" : "bezig")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
    }
}

#Preview {
    VaultWalletChecks(done: 2)
        .padding(24)
}
