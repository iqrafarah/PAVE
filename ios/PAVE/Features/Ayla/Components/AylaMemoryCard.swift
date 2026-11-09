import PAVECore
import SwiftUI

/// Under Ayla's answer when she suggests remembering something: you decide. Once kept, a short line says so and
/// leads to everything Ayla remembers.
struct AylaMemoryCard: View {
    let suggestion: AylaReply.MemorySuggestion
    let decision: AylaMemoryModel.Decision?
    let onKeep: () -> Void
    let onDecline: () -> Void
    let onShowMemory: () -> Void

    var body: some View {
        switch decision {
        case .saved:
            saved
        case .declined:
            EmptyView()
        case nil, .saving, .failed:
            question
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PaveMark()
                Text("Zal ik dit onthouden?")
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
            }
            Text(suggestion.text)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if decision == .failed {
                Text("Onthouden lukte niet. Probeer het opnieuw.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.criticalInk)
            }
            HStack(spacing: 8) {
                Button {
                    PaveHaptics.tap(.medium)
                    onKeep()
                } label: {
                    Group {
                        if decision == .saving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Onthouden")
                        }
                    }
                    .textStyle(.label)
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 96, minHeight: 36)
                    .padding(.horizontal, 14)
                    .background(Color.brandGreen, in: .capsule)
                }
                .buttonStyle(.pave)
                .disabled(decision == .saving)

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
        .frame(maxWidth: 300, alignment: .leading)
        .background(Color.surfaceTint.opacity(0.6), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
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
        AylaMemoryCard(suggestion: .init(text: "Je hebt stage gelopen bij LiveWall."), decision: nil, onKeep: {}, onDecline: {}, onShowMemory: {})
        AylaMemoryCard(suggestion: .init(text: "Je hebt stage gelopen bij LiveWall."), decision: .saved, onKeep: {}, onDecline: {}, onShowMemory: {})
    }
    .padding()
    .background(Color.canvas)
}
