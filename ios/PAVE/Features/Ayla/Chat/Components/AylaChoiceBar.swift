import SwiftUI

struct AylaChoice: Identifiable, Equatable {
    let id: String
    let label: String
}

/// Two or three answers from Ayla's question, shown in place of the text field. A question about the vault shows
/// "Kluis" with the folder above the choices, as on the web (Figma 976:7971). Next to each other when they fit on one
/// line each, and under each other when they do not (three answers on a narrow screen, or large text), so a label is
/// never cut off.
struct AylaChoiceBar: View {
    let choices: [AylaChoice]
    var isAboutVault = false
    /// The choice a nod or a head shake picked: it lights up a moment before it is sent.
    var picked: String?
    let onChoose: (AylaChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isAboutVault {
                HStack(spacing: 6) {
                    Image(.iconFolderSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(16)
                        .foregroundStyle(Color.paveAccent)
                        .accessibilityHidden(true)
                    Text(AylaMessages.vaultLabel)
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                }
                .padding(.leading, 14)
                .transition(.opacity)
            }
            choiceRow
        }
    }

    private var choiceRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 3.2) {
                ForEach(choices) { button($0, onOneLine: true) }
            }
            .padding(8.15)
            .background(Color.paveSurfaceTint, in: .capsule)

            VStack(spacing: 4) {
                ForEach(choices) { button($0, onOneLine: false) }
            }
            .padding(8.15)
            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 33))
        }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: picked)
    }

    /// `onOneLine`: the label keeps its own width, so the row only counts as fitting when no label has to break.
    private func button(_ choice: AylaChoice, onOneLine: Bool) -> some View {
        Button {
            onChoose(choice)
        } label: {
            Text(choice.label)
                .textStyle(.choice)
                .foregroundStyle(picked == choice.id ? Color.white : Color.ink)
                .lineLimit(onOneLine ? 1 : 3)
                .fixedSize(horizontal: onOneLine, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 53)
                .background(picked == choice.id ? Color.paveAccentFill : Color.panel, in: .rect(cornerRadius: 25))
                .scaleEffect(picked == choice.id ? 1.04 : 1)
                .contentShape(.rect(cornerRadius: 25))
        }
        .buttonStyle(.pave)
    }
}

#Preview {
    AylaChoiceBar(choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")]) { _ in }
        .padding(.leading, 21)
        .padding(.trailing, 22)
        .background(Color.canvas)
}
