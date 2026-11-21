import SwiftUI

/// While Ayla reads: the shape of the form she is about to fill in, with light sweeping across it, so the step after
/// it lands in the same place.
struct VaultAylaFillSkeleton: View {
    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var isDim = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                AylaLetter()
                    .opacity(isDim ? 0.45 : 1)
                    .paveIconFrame(32)
                    .background(Color.paveAccentFill, in: .rect(cornerRadius: 8))
                Text(VaultMessages.aylaFillReading)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    field(labelWidth: 44)
                    field(labelWidth: 96)
                }
                HStack(alignment: .top, spacing: 14) {
                    field(labelWidth: 130)
                    field(labelWidth: 60)
                }
                field(labelWidth: 90, height: 114)
            }
            .paveShimmer()
            .accessibilityHidden(true)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isDim = true }
        }
        .accessibilityElement(children: .combine)
    }

    private func field(labelWidth: CGFloat, height: CGFloat = 44) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(Color.tileFill).frame(width: labelWidth, height: 14)
            RoundedRectangle(cornerRadius: 7).fill(Color.tileFill).frame(height: height)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VaultAylaFillSkeleton()
        .padding(24)
}
