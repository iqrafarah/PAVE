import PAVECore
import SwiftUI

/// What Ayla should stress in the profile and the letter: a few words of your own, with what the vacancy asks for and
/// you have as quick picks.
struct ApplicationFocusField: View {
    let model: ApplicationStudioModel

    private var text: String { model.draft.focus ?? "" }
    /// What fits between you and the vacancy, as a start.
    private var suggestions: [String] {
        var seen = Set<String>()
        return model.draft.vacancy.matches.map(\.skill).filter { seen.insert($0.lowercased()).inserted }.prefix(4).map { $0 }
    }

    private func parts() -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func has(_ suggestion: String) -> Bool {
        parts().contains { $0.caseInsensitiveCompare(suggestion) == .orderedSame }
    }

    private func toggle(_ suggestion: String) {
        var parts = parts()
        if has(suggestion) {
            parts.removeAll { $0.caseInsensitiveCompare(suggestion) == .orderedSame }
        } else {
            parts.append(suggestion)
        }
        model.setFocus(parts.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VaultFormField(title: ApplyMessages.focus, isRequired: false, note: ApplyMessages.focusHint) {
                TextField("", text: Binding(get: { text }, set: { model.setFocus($0) }), prompt: Text(ApplyMessages.focusPrompt).foregroundStyle(Color.inkMuted))
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .submitLabel(.done)
            }
            if !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        let isOn = has(suggestion)
                        Button(suggestion) {
                            PaveHaptics.selection()
                            toggle(suggestion)
                        }
                        .textStyle(.chip)
                        .foregroundStyle(isOn ? Color.white : Color.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
                        .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
                        .frame(minHeight: 44)
                        .contentShape(.capsule)
                        .buttonStyle(.pave)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
        }
    }
}
