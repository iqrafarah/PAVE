import PAVECore
import SwiftUI
import WatchKit

/// PAVE on the Watch: Ayla's pixel orb, the same as in the voice mode on the iPhone. Tap it and talk; it moves with
/// your voice while it listens, swirls while Ayla thinks, and moves with her voice while she answers. What she says is
/// only heard, not shown: text comes under the orb only when she asks you something, with her choices such as Ja and
/// Nee, a proposal or "Zal ik dit onthouden?". A new conversation starts from the menu (long press).
struct WatchVoiceView: View {
    @Bindable var model: WatchAylaModel
    @State private var showsMenu = false
    /// A short squeeze of the orb when you tap it, so it feels like she reacts.
    @State private var isPressed = false
    /// Long pressing is easy to miss, so a hint shows until the menu has been opened once.
    @AppStorage("watchMenuDiscovered") private var menuDiscovered = false

    /// Ayla asks something you answer on the screen; otherwise her answer is only spoken.
    private var hasAnswer: Bool {
        guard let reply = model.reply else { return false }
        return !(reply.question?.choices.isEmpty ?? true) || model.proposal != nil || model.remember != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                orb
                    .frame(width: hasAnswer ? 78 : 124, height: hasAnswer ? 78 : 124)
                    .background {
                        WatchOrbAura(phase: model.phase, meter: model.meter)
                            .frame(width: hasAnswer ? 118 : 184, height: hasAnswer ? 118 : 184)
                    }
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .padding(.top, hasAnswer ? 0 : 6)
                Text(status)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(isFailure ? Color.primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if hasAnswer, let reply = model.reply {
                    answer(reply)
                }
                if !menuDiscovered {
                    Text("Houd ingedrukt voor je gesprekken")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy(duration: 0.35), value: hasAnswer)
            .animation(.easeOut(duration: 0.2), value: status)
        }
        .containerBackground(for: .navigation) { WatchBackdrop(phase: model.phase) }
        // A long press anywhere on the background opens the menu; the orb itself keeps its tap.
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0.6) { openMenu() }
        .accessibilityAction(named: "Menu en gesprekken") { openMenu() }
        .sheet(isPresented: $showsMenu) {
            WatchMenuView(model: model)
        }
    }

    private func openMenu() {
        model.pause()
        WKInterfaceDevice.current().play(.click)
        menuDiscovered = true
        showsMenu = true
    }

    private var orb: some View {
        AylaPixelOrb(mode: model.orbMode, meter: model.meter, icon: { model.icon(at: $0) })
            .contentShape(.circle)
            .onTapGesture {
                withAnimation(.spring(duration: 0.18)) { isPressed = true }
                withAnimation(.spring(duration: 0.45, bounce: 0.5).delay(0.12)) { isPressed = false }
                model.tapOrb()
            }
            .accessibilityElement()
            .accessibilityLabel("Ayla")
            .accessibilityValue(status)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.tapOrb() }
    }

    private var status: String {
        switch model.phase {
        case .ready: WatchMessages.tapToTalk
        case .listening: model.reply == nil ? WatchMessages.listening : WatchMessages.listeningAgain
        case .understanding: WatchMessages.understanding
        case .thinking: WatchMessages.thinking
        case .speaking: WatchMessages.speaking
        case .answer: WatchMessages.tapToAskAgain
        case .failed(let message): message
        }
    }

    private var isFailure: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var hint: String {
        switch model.phase {
        case .listening: "Tik als je klaar bent"
        case .speaking: "Tik om Ayla te onderbreken"
        default: "Tik en praat"
        }
    }

    private func answer(_ reply: AylaReply) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let choices = reply.question?.choices, !choices.isEmpty {
                // Her question itself, so you know what Ja or Nee answers.
                Text(reply.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(choices.prefix(3), id: \.id) { choice in
                    Button(choice.label) { model.choose(choice) }
                        .buttonStyle(.bordered)
                }
            }
            if let proposal = model.proposal {
                WatchProposalCard(proposal: proposal) { model.answerProposal($0) }
            }
            if let remember = model.remember {
                WatchRememberCard(remember: remember) { model.answerRemember($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
