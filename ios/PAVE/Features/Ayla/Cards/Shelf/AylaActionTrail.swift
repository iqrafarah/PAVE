import SwiftUI

/// One thing Ayla does in the app, as a line you can follow.
struct AylaActionStep: Identifiable, Equatable {
    enum State {
        case waiting, running, done, failed
    }

    let id: Int
    let title: String
    var state = State.waiting
}

/// What Ayla is doing in the app right now, step by step: the one she is on, the ones done, and what did not work.
/// It shows in the chat and on top of an open page, so you follow her also when you only talk.
struct AylaActionTrail: View {
    let steps: [AylaActionStep]

    @Environment(\.paveAnimationsOff) private var animationsOff

    private var isBusy: Bool { steps.contains { $0.state == .waiting || $0.state == .running } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                Text(isBusy ? AylaMessages.actionsBusy : AylaMessages.actionsDone)
                    .textStyle(.caption)
                    .foregroundStyle(Color.paveAccent)
            }
            ForEach(steps) { step in
                HStack(alignment: .center, spacing: 8) {
                    mark(step.state)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(step.title)
                        .textStyle(.caption)
                        .foregroundStyle(step.state == .waiting ? Color.inkMuted : Color.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(step.title), \(AylaMessages.actionState(step.state))")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 600, alignment: .leading)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 18))
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: steps)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AylaMessages.actionsBusy)
    }

    @ViewBuilder
    private func mark(_ state: AylaActionStep.State) -> some View {
        switch state {
        case .waiting:
            Image(systemName: "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkMuted.opacity(0.6))
        case .running:
            if animationsOff {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.paveAccent)
            } else {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.paveAccent)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.paveAccent)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.criticalInk)
        }
    }
}

#Preview {
    AylaActionTrail(steps: [
        AylaActionStep(id: 0, title: "Donker aanzetten", state: .done),
        AylaActionStep(id: 1, title: "Tekst groter maken", state: .running),
        AylaActionStep(id: 2, title: "Map Stages openen"),
    ])
    .padding()
}
