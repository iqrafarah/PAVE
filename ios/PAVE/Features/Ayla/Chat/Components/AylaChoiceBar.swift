import SwiftUI

struct AylaChoice: Identifiable, Equatable {
    let id: String
    let label: String
}

/// Two or three answers from Ayla's question, shown in place of the text field. A question about the vault shows
/// "Kluis" with the folder above the choices, as on the web (Figma 976:7971).
struct AylaChoiceBar: View {
    let choices: [AylaChoice]
    var isAboutVault = false
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
        HStack(spacing: 3.2) {
            ForEach(choices) { choice in
                Button {
                    onChoose(choice)
                } label: {
                    Text(choice.label)
                        .textStyle(.choice)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 53)
                        .background(Color.white, in: .rect(cornerRadius: 25))
                        .contentShape(.rect(cornerRadius: 25))
                }
                .buttonStyle(.pave)
            }
        }
        .padding(8.15)
        .background(Color.paveSurfaceTint, in: .capsule)
    }
}

#Preview {
    AylaChoiceBar(choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")]) { _ in }
        .padding(.leading, 21)
        .padding(.trailing, 22)
        .background(Color.canvas)
}
