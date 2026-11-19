import SwiftUI

/// Above Ja and Nee while AirPods follow the head: that a nod or a head shake answers, and then what was understood.
struct AylaHeadHint: View {
    let text: String
    let isAnswer: Bool

    var body: some View {
        Text(text)
            .textStyle(.meta)
            .foregroundStyle(isAnswer ? Color.white : Color.ink)
            .contentTransition(.opacity)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(isAnswer ? Color.paveAccent : Color.panel, in: .capsule)
            .overlay { Capsule().strokeBorder(isAnswer ? Color.clear : Color.cardBorder, lineWidth: 1) }
    }
}
