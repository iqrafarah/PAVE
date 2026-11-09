import SwiftUI

/// Takes the place of the text field while you dictate, like ChatGPT: your words appear as you speak, the pixel wave
/// moves with your voice, and the timer runs. ✕ throws the recording away; ✓ keeps the text in the field, so you
/// can read and change it before you send it.
struct AylaDictationBar: View {
    let text: String
    let meter: VoiceMeter
    let startedAt: Date
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text.isEmpty ? "Ik luister…" : text)
                .textStyle(.bodyMedium)
                .foregroundStyle(text.isEmpty ? Color.inkMuted : .ink)
                .lineLimit(3)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .accessibilityLabel(text.isEmpty ? "Ik luister" : text)

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Image(.iconPlus)
                        .renderingMode(.template)
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(Color.ink)
                        .frame(width: 44, height: 53)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Opname weggooien")

                PixelLevelWave(meter: meter)
                    .frame(maxWidth: .infinity)

                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                    .textStyle(.meta)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)

                Button(action: onDone) {
                    Image(.iconCheck)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.white)
                        .frame(width: 30, height: 30)
                        .background(Color.brandGreen, in: .circle)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                        .frame(width: AylaComposer.roundButtonWidth, height: 53)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Klaar, tekst bewaren")
            }
            .padding(.leading, 4.5)
            .padding(.trailing, 7)
        }
        .glassEffect(.clear, in: .rect(cornerRadius: 25))
    }
}

#Preview {
    VStack(spacing: 20) {
        AylaDictationBar(text: "", meter: VoiceMeter(), startedAt: .now, onCancel: {}, onDone: {})
        AylaDictationBar(text: "Welke banen passen bij mijn stage bij LiveWall", meter: VoiceMeter(), startedAt: .now, onCancel: {}, onDone: {})
    }
    .padding(.horizontal, 32)
    .background(Color.canvas)
}
