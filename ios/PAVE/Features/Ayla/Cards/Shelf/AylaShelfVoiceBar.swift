import SwiftUI

/// At the bottom of a page that opened while you talk with Ayla: she is still there as the small orb, alive with her
/// voice and yours, with what she is doing next to it, the microphone and stop. So you see the page and her.
struct AylaShelfVoiceBar: View {
    let mode: AylaPixelOrb.Mode
    let meter: VoiceMeter?
    let status: String
    let isMuted: Bool
    let onTapOrb: () -> Void
    let onMute: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTapOrb) {
                AylaPixelOrb(mode: mode, meter: meter)
                    .frame(width: 48, height: 48)
                    .frame(width: 56, height: 56)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Ayla")
            .accessibilityHint(mode == .speaking ? "Tik om Ayla te onderbreken" : "Tik om je vraag nu te versturen")

            Text(status)
                .textStyle(.status)
                .foregroundStyle(Color.paveAccent)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: status)

            Button(action: onMute) {
                Image(.iconMicrophone)
                    .renderingMode(.template)
                    .foregroundStyle(isMuted ? Color.inkMuted : .ink)
                    .overlay {
                        if isMuted {
                            Capsule()
                                .fill(Color.criticalInk)
                                .frame(width: 2.5, height: 24)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.panel, in: .circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder) }
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isMuted ? "Microfoon aanzetten" : "Microfoon uitzetten")

            Button(action: onStop) {
                Image(.iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .paveIconFrame(14)
                    .rotationEffect(.degrees(45))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(Color.paveAccentFill, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Gesprek stoppen")
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
