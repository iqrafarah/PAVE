import PAVECore
import SwiftUI

/// Under Ayla's answer when she suggests remembering something, or taking away something that is no longer true:
/// you decide. Every change is its own line with its category; with more than one, untick what should not happen.
/// An old note you leave ticked off simply stays, because you can have two jobs at once. Once done, a short line says
/// so and leads to everything Ayla remembers.
struct AylaMemoryCard: View {
    let changes: [AylaMemoryModel.Change]
    /// The reply took old notes away, so the line afterwards says "Bijgewerkt".
    let didUpdate: Bool
    let decision: AylaMemoryModel.Decision?
    let onConfirm: ([AylaMemoryModel.Change]) -> Void
    let onDecline: () -> Void
    let onShowMemory: () -> Void

    @State private var unticked: Set<AylaMemoryModel.Change> = []
    /// The explaining lines show until you used a card once: after that you know how it works.
    @AppStorage("aylaMemoryCardExplained") private var isExplained = false
    @AppStorage("aylaMemoryRemovalExplained") private var isRemovalExplained = false

    private var chosen: [AylaMemoryModel.Change] {
        changes.filter { !unticked.contains($0) }
    }

    private var removals: Int {
        changes.filter(\.isRemoval).count
    }

    var body: some View {
        switch decision {
        case .saved:
            done
        case .declined, .known:
            EmptyView()
        case nil, .saving, .failed:
            if !changes.isEmpty { question }
        }
    }

    private var title: String {
        if removals == changes.count { return "Zal ik dit weghalen?" }
        if removals > 0 { return "Zal ik dit bijwerken?" }
        return changes.count == 1 ? "Zal ik dit onthouden?" : "Zal ik dit over je onthouden?"
    }

    private var confirmTitle: String {
        let removes = chosen.contains(where: \.isRemoval)
        let keeps = chosen.contains { !$0.isRemoval }
        if removes && keeps { return "Bijwerken" }
        if removes { return "Weghalen" }
        let keepCount = changes.filter { !$0.isRemoval }.count
        let chosenKeeps = chosen.filter { !$0.isRemoval }.count
        if keepCount > 1, chosenKeeps < keepCount { return "Onthoud \(chosenKeeps)" }
        return "Onthouden"
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PaveMark()
                Text(title)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(changes) { change in
                    line(change)
                }
            }
            if removals > 0, !isRemovalExplained {
                Text("Laat je het weghalen uit, dan blijft het gewoon staan.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            if decision == .failed {
                Text("Dat lukte niet. Probeer het opnieuw.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.criticalInk)
            }
            HStack(spacing: 8) {
                Button {
                    PaveHaptics.tap(.medium)
                    markExplained()
                    onConfirm(chosen)
                } label: {
                    Group {
                        if decision == .saving {
                            ProgressView().tint(.white)
                        } else {
                            Text(confirmTitle)
                        }
                    }
                    .textStyle(.label)
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 96, minHeight: 36)
                    .padding(.horizontal, 14)
                    .background(Color.brandGreen, in: .capsule)
                    .opacity(chosen.isEmpty ? 0.4 : 1)
                }
                .buttonStyle(.pave)
                .disabled(decision == .saving || chosen.isEmpty)

                Button {
                    PaveHaptics.tap(.light)
                    markExplained()
                    onDecline()
                } label: {
                    Text("Nee, niet nodig")
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                        .frame(minHeight: 36)
                        .padding(.horizontal, 14)
                        .background(Color.white, in: .capsule)
                }
                .buttonStyle(.pave)
                .disabled(decision == .saving)
            }
            if !isExplained {
                Text("Je ziet en wist alles wat Ayla onthoudt in Instellingen.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color.surfaceTint.opacity(0.6), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func markExplained() {
        isExplained = true
        if removals > 0 { isRemovalExplained = true }
    }

    /// A fact to keep, or an old note to take away (struck through). With more than one line, tap it to tick it.
    @ViewBuilder
    private func line(_ change: AylaMemoryModel.Change) -> some View {
        // An old note is only struck through while it is ticked to go.
        let goes = change.isRemoval && !unticked.contains(change)
        let label = VStack(alignment: .leading, spacing: 3) {
            Text(change.isRemoval ? "Weghalen uit \(change.suggestion.category.title.lowercased())" : change.suggestion.category.title)
                .textStyle(.caption)
                .foregroundStyle(change.isRemoval ? Color.criticalInk : .brandGreen)
            Text(change.text)
                .textStyle(.bodyMedium)
                .foregroundStyle(goes ? Color.inkMuted : .ink)
                .strikethrough(goes, color: .inkMuted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        if changes.count > 1 {
            let isOn = !unticked.contains(change)
            Button {
                PaveHaptics.selection()
                if isOn { unticked.insert(change) } else { unticked.remove(change) }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    PaveCheckbox(isOn: isOn)
                        .padding(.top, 2)
                    label
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(decision == .saving)
            .accessibilityLabel(change.isRemoval ? "Weghalen: \(change.text)" : "\(change.suggestion.category.title): \(change.text)")
            .accessibilityAddTraits(isOn ? .isSelected : [])
        } else {
            label
                .accessibilityElement(children: .combine)
        }
    }

    private var done: some View {
        Button(action: onShowMemory) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
                Text(didUpdate ? "Bijgewerkt" : "Onthouden")
                Text("·").accessibilityHidden(true)
                Text("Bekijk wat Ayla weet")
                    .underline()
            }
            .textStyle(.caption)
            .foregroundStyle(Color.brandGreen)
            .padding(.leading, 4)
        }
        .buttonStyle(.pave)
        .accessibilityLabel("\(didUpdate ? "Bijgewerkt" : "Onthouden"). Bekijk wat Ayla over je weet")
    }
}

extension AylaMemoryModel.Change {
    var isRemoval: Bool {
        if case .remove = kind { true } else { false }
    }

    /// What the line says: the new fact, or the old note that would go.
    var text: String {
        switch kind {
        case .keep: suggestion.text
        case .remove(let note): note.text
        }
    }
}

#Preview {
    let old = AylaMemory(id: "1", text: "Je werkt als leidinggevende bij de Plus.", category: .work, source: .ayla, createdAt: .now)
    let suggestion = AylaReply.MemorySuggestion(text: "Je werkt bij Albert Heijn.", category: .work, replaces: old.text)
    VStack(alignment: .leading, spacing: 24) {
        AylaMemoryCard(
            changes: [.init(suggestion: suggestion, kind: .keep), .init(suggestion: suggestion, kind: .remove(old))],
            didUpdate: false, decision: nil, onConfirm: { _ in }, onDecline: {}, onShowMemory: {}
        )
        AylaMemoryCard(changes: [], didUpdate: true, decision: .saved, onConfirm: { _ in }, onDecline: {}, onShowMemory: {})
    }
    .padding()
    .background(Color.canvas)
}
