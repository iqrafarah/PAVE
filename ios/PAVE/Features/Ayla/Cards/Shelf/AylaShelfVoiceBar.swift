import SwiftUI

/// On a page that opened while you talk with Ayla: she stays with you as the small orb, in one floating capsule with
/// what she is doing, the microphone and stop. It is part of the layer of controls over the page, so the page itself
/// stays whole and scrolls on under it.
struct AylaShelfVoiceBar: View {
    let mode: AylaPixelOrb.Mode
    let meter: VoiceMeter?
    let status: String
    let isMuted: Bool
    let onTapOrb: () -> Void
    let onMute: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTapOrb) {
                HStack(spacing: 10) {
                    // On a ground of its own, so her blocks read over whatever page is under the glass.
                    AylaPixelOrb(mode: mode, meter: meter)
                        .frame(width: 46, height: 46)
                        .frame(width: 54, height: 54)
                        .background(Color.panel, in: .circle)
                    Text(status)
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.2), value: status)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 7)
                .frame(minHeight: 68)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ayla, \(status)")
            .accessibilityHint(mode == .speaking ? "Tik om Ayla te onderbreken" : "Tik om je vraag nu te versturen")

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
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isMuted ? "Microfoon aanzetten" : "Microfoon uitzetten")

            Button(action: onStop) {
                Image(.iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .paveIconFrame(13)
                    .rotationEffect(.degrees(45))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.paveAccentFill, in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Gesprek stoppen")
        }
        .padding(.trailing, 10)
        // Tinted with the page's own white, so text under the glass never runs through her status.
        .glassEffect(.regular.tint(Color.panel.opacity(0.78)), in: .capsule)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}
