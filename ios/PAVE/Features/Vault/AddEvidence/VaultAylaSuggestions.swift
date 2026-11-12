import PAVECore
import SwiftUI

/// The "Voorstel van Ayla" box: first a short explanation and a button, then her proposals as dark green rows.
struct VaultAylaSuggestions: View {
    @Bindable var ayla: VaultAylaSkills
    let isChosen: (String) -> Bool
    let onToggle: (String) -> Void
    let onAsk: () -> Void

    var body: some View {
        Group {
            switch ayla.state {
            case .idle:
                prompt(VaultMessages.aylaSkillsIntro, button: VaultMessages.aylaSkillsAsk)
            case .loading:
                AylaStatusIndicator(state: .thinking, message: VaultMessages.aylaSkillsThinking)
                    .padding(.vertical, 18)
            case .loaded(let suggestions) where suggestions.isEmpty:
                prompt(VaultMessages.aylaSkillsNone, button: VaultMessages.aylaSkillsAgain)
            case .loaded(let suggestions):
                VStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        VaultSkillRow(name: suggestion.name, detail: suggestion.reason, style: .ayla, isChosen: isChosen(suggestion.name)) {
                            onToggle(suggestion.name)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            case .failed(let message):
                prompt(message, button: VaultMessages.aylaSkillsAgain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.railBorder, lineWidth: 1) }
        .animation(.snappy(duration: 0.35), value: ayla.state)
    }

    private func prompt(_ text: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAsk) {
                Text(button)
                    .textStyle(.gapChip)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.brandGreen, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pave)
        }
        .padding(4)
    }
}
