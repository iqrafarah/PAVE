import SwiftUI

/// What Ayla is doing in the app, in one line: her blocks, the step she is on and how far she is. It starts closed;
/// a tap opens the steps, so the detail is there when you want it and out of the way when you do not. It floats just
/// above where she lives (the text field or the small orb), in the chat and on an open page alike.
struct AylaActivityPill: View {
    let steps: [AylaActionStep]

    @State private var isOpen = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    private var finished: Int { steps.count { $0.state == .done || $0.state == .failed } }
    private var failed: Int { steps.count { $0.state == .failed } }
    private var isBusy: Bool { finished < steps.count }

    private var title: String {
        if let step = steps.first(where: { $0.state == .running }) ?? steps.first(where: { $0.state == .waiting }) { return step.title }
        return AylaMessages.actionsSummary(done: finished - failed, failed: failed, failedStep: steps.first { $0.state == .failed }?.title)
    }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.12)) { isOpen.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                if isOpen {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(steps) { step in
                            HStack(spacing: 10) {
                                AylaStepMark(state: step.state)
                                Text(step.title)
                                    .textStyle(.chip)
                                    .foregroundStyle(step.state == .waiting ? Color.inkMuted : Color.ink)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(step.title), \(AylaMessages.actionState(step.state))")
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }
                HStack(spacing: 10) {
                    AylaStepBlocks(steps: steps)
                    Text(title)
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isBusy, steps.count > 1 {
                        Text("\(min(finished + 1, steps.count)) van \(steps.count)")
                            .textStyle(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkMuted)
                    }
                    Image(.iconChevronDown)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconHeight(6)
                        .foregroundStyle(Color.inkMuted)
                        .rotationEffect(.degrees(isOpen ? 0 : 180))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.pave)
        // Tinted with the page's own white, so what is under the glass never runs through the step.
        .glassEffect(.regular.tint(Color.panel.opacity(0.78)), in: .rect(cornerRadius: 22))
        .frame(maxWidth: 420)
        // Its own height, whatever room it is given: over the text field that room is the height of the field, and
        // the open steps then ran out of their glass, over the conversation.
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeOut(duration: 0.2), value: steps)
        .accessibilityElement(children: isOpen ? .contain : .ignore)
        .accessibilityLabel("\(AylaMessages.actionsBusy): \(title)")
        .accessibilityHint(isOpen ? "Tik om de stappen te verbergen" : "Tik om de stappen te zien")
    }
}

#Preview {
    VStack(spacing: 20) {
        AylaActivityPill(steps: [
            AylaActionStep(id: 0, title: "Donker aanzetten", state: .done),
            AylaActionStep(id: 1, title: "Map Stages openen", state: .running),
            AylaActionStep(id: 2, title: "Chat Sollicitatie Philips noemen"),
        ])
        AylaActivityPill(steps: [
            AylaActionStep(id: 0, title: "Donker aanzetten", state: .done),
            AylaActionStep(id: 1, title: "Map Vakantie openen", state: .failed),
        ])
    }
    .padding()
    .background(Color.canvas)
}
