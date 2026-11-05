import SwiftUI

struct AylaChoiceBar: View {
    let choices: [AylaChoice]
    let onChoose: (AylaChoice) -> Void

    var body: some View {
        HStack(spacing: 4) {
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
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 35))
    }
}

struct AylaChoice: Identifiable, Equatable {
    let id: String
    let label: String
}

#Preview {
    AylaChoiceBar(choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")]) { _ in }
        .padding(24)
        .background(Color.canvas)
}
