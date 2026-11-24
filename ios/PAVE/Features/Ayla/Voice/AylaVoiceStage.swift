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
/// With vacancies the orb moves up and becomes small, so the cards get the room: they are what you look at then.
/// The orb itself is drawn above everything by `AylaOrbTrack`, so it can glide between here and the voice bar;
/// this only keeps its place free and says where that is.
struct AylaVoiceStage: View {
    let caption: AylaVoiceCaption
    /// The caption fades as the orb is pulled, and only shows while the orb is large in its place.
    var motion: AylaOrbMotion?
    /// Off in Settings: no line at all, and the orb sits in the middle of the room on its own.
    var showsText = true
    var onOrbFrame: (CGRect) -> Void = { _ in }
    /// Where the caption is on screen, so the field around the orb leaves it clear.
    var onCaptionFrame: (CGRect) -> Void = { _ in }
    /// The vacancies Ayla found, under the small orb.
    var deck: AylaVoiceVacancyDeck?
    /// A practice interview is going on: which one, with a way to stop.
    var practice: VacancyPracticeBar?
    /// What she is doing in the app, under her caption, where the orb does not cover it.
    var activity: AylaActivityPill?

    @Environment(\.paveReduceMotion) private var reduceMotion

    private var isCompact: Bool { deck != nil }

    var body: some View {
        VStack(spacing: isCompact ? 14 : 44) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: isCompact ? 96 : 240)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onOrbFrame($0) }
            if showsText {
                captionText
                    .padding(.horizontal, 32)
            }
            if let activity {
                activity
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let practice {
                practice
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }
            if let deck {
                deck
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: isCompact ? .infinity : nil, alignment: .top)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: isCompact)
    }

    private var captionText: some View {
        Text(caption.text)
            .textStyle(caption.kind == .status || isCompact ? .bodyMedium : .listTitle)
            .foregroundStyle(caption.kind == .status ? Color.inkMuted : .ink)
            .multilineTextAlignment(.center)
            .lineLimit(isCompact ? 3 : 6)
            .truncationMode(caption.kind == .heard ? .head : .tail)
            .frame(maxWidth: 313, minHeight: isCompact ? 44 : 96, alignment: .top)
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.2), value: caption)
            .modifier(AylaOrbFade(motion: motion) { $0.isLow || !$0.hasArrived ? 0 : 1 - Double($0.stretch) * 0.7 })
            .animation(.easeOut(duration: 0.25), value: motion.map { !$0.isLow && $0.hasArrived } ?? true)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onCaptionFrame($0) }
    }
}

#Preview {
    AylaVoiceStage(caption: .init(text: "Ik luister.", kind: .status))
        .background(Color.canvas)
}
