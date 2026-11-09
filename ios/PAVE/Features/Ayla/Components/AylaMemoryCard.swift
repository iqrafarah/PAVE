import PAVECore
import SwiftUI

/// Under Ayla's answer when she suggests remembering something: you decide. Every fact is its own line with its
/// category; with more than one, untick what Ayla should not keep. Once kept, a short line says so and leads to
/// everything Ayla remembers.
struct AylaMemoryCard: View {
    let suggestions: [AylaReply.MemorySuggestion]
    let decision: AylaMemoryModel.Decision?
    let onKeep: ([AylaReply.MemorySuggestion]) -> Void
    let onDecline: () -> Void
    let onShowMemory: () -> Void

    @State private var unticked: Set<AylaReply.MemorySuggestion> = []

    private var chosen: [AylaReply.MemorySuggestion] {
        suggestions.filter { !unticked.contains($0) }
    }

    var body: some View {
        switch decision {
        case .saved:
            saved
        case .declined, .known:
            EmptyView()
        case nil, .saving, .failed:
            if !suggestions.isEmpty { question }
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PaveMark()
                Text(suggestions.count == 1 ? "Zal ik dit onthouden?" : "Zal ik dit over je onthouden?")
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    fact(suggestion)
                }
            }
            if decision == .failed {
                Text("Onthouden lukte niet. Probeer het opnieuw.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.criticalInk)
            }
            HStack(spacing: 8) {
                Button {
                    PaveHaptics.tap(.medium)
                    onKeep(chosen)
                } label: {
                    Group {
                        if decision == .saving {
                            ProgressView().tint(.white)
                        } else {
                            Text(suggestions.count > 1 && chosen.count < suggestions.count ? "Onthoud \(chosen.count)" : "Onthouden")
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
            Text("Je ziet en wist alles wat Ayla onthoudt in Instellingen.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(14)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color.surfaceTint.opacity(0.6), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    /// One fact with its category. With more than one fact, tap it to tick or untick it.
    @ViewBuilder
    private func fact(_ suggestion: AylaReply.MemorySuggestion) -> some View {
        let label = VStack(alignment: .leading, spacing: 3) {
            Text(suggestion.category.title)
                .textStyle(.caption)
                .foregroundStyle(Color.brandGreen)
            Text(suggestion.text)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        if suggestions.count > 1 {
            let isOn = !unticked.contains(suggestion)
            Button {
                PaveHaptics.selection()
                if isOn { unticked.insert(suggestion) } else { unticked.remove(suggestion) }
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
            .accessibilityLabel("\(suggestion.category.title): \(suggestion.text)")
            .accessibilityAddTraits(isOn ? .isSelected : [])
        } else {
            label
        }
    }

    private var saved: some View {
        Button(action: onShowMemory) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
                Text("Onthouden")
                Text("·").accessibilityHidden(true)
                Text("Bekijk wat Ayla weet")
                    .underline()
            }
            .textStyle(.caption)
            .foregroundStyle(Color.brandGreen)
            .padding(.leading, 4)
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Onthouden. Bekijk wat Ayla over je weet")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        AylaMemoryCard(
            suggestions: [
                .init(text: "Je studeert ICT aan Fontys.", category: .education),
                .init(text: "Je werkt als leidinggevende bij de Plus.", category: .work),
            ],
            decision: nil, onKeep: { _ in }, onDecline: {}, onShowMemory: {}
        )
        AylaMemoryCard(suggestions: [.init(text: "Je woont in Eindhoven.")], decision: .saved, onKeep: { _ in }, onDecline: {}, onShowMemory: {})
    }
    .padding()
    .background(Color.canvas)
}
