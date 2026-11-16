import PAVECore
import SwiftUI

/// The line under the orb while talking.
struct AylaVoiceCaption: Equatable {
    enum Kind {
        /// A hint or what Ayla is doing, in grey.
        case status
        /// What you are saying: the newest words stay in view.
        case heard
        /// What Ayla answers: the start stays in view.
        case answer
    }

    let text: String
    let kind: Kind
}

/// Talking with Ayla full screen, like the separate voice mode of ChatGPT: the orb large in the middle, with one
/// caption underneath (what you say, what Ayla answers, or what she is doing). The conversation itself keeps
/// growing behind it: drag the orb down to see it (the caption fades as you drag), or stop talking.
/// The orb itself is drawn above everything by `AylaOrbTrack`, so it can glide between here and the voice bar;
/// this only keeps its place free and says where that is.
struct AylaVoiceStage: View {
    let caption: AylaVoiceCaption
    /// The caption fades as the orb is pulled, and only shows while the orb is large in its place.
    var motion: AylaOrbMotion?
    /// Off in Settings: no line at all, but its place stays, so the orb does not move.
    var showsText = true
    var onOrbFrame: (CGRect) -> Void = { _ in }
    /// Where the caption is on screen, so the field around the orb leaves it clear.
    var onCaptionFrame: (CGRect) -> Void = { _ in }

    var body: some View {
        // Well below the orb, clear of the ring that moves around it.
        VStack(spacing: 44) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 240)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onOrbFrame($0) }
            Text(caption.text)
                .textStyle(caption.kind == .status ? .bodyMedium : .listTitle)
                .foregroundStyle(caption.kind == .status ? Color.inkMuted : .ink)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .truncationMode(caption.kind == .heard ? .head : .tail)
                .frame(maxWidth: 313, minHeight: 96, alignment: .top)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: caption)
                .modifier(AylaOrbFade(motion: motion) { $0.isLow || !$0.hasArrived ? 0 : 1 - Double($0.stretch) * 0.7 })
                .animation(.easeOut(duration: 0.25), value: motion.map { !$0.isLow && $0.hasArrived } ?? true)
                .opacity(showsText ? 1 : 0)
                .accessibilityHidden(!showsText)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onCaptionFrame($0) }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AylaVoiceStage(caption: .init(text: "Ik luister.", kind: .status))
        .background(Color.canvas)
}
