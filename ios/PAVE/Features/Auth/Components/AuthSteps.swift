import SwiftUI

/// Where you are in a flow of several screens, like `AuthSteps.vue` on the web: done steps get a check,
/// the current one is filled, the rest stay open.
struct AuthSteps: View {
    let steps: [String]
    let currentIndex: Int

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                VStack(spacing: 6) {
                    ZStack {
                        HStack(spacing: 0) {
                            line(isVisible: index > 0, isDone: index <= currentIndex)
                            line(isVisible: index < steps.count - 1, isDone: index + 1 <= currentIndex)
                        }
                        circle(index: index)
                    }
                    .frame(height: 24)
                    Text(Self.breakingAfterHyphen(title))
                        .textStyle(.caption)
                        .foregroundStyle(index == currentIndex ? Color.ink : .inkMuted)
                        .multilineTextAlignment(.center)
                        .allowsTightening(true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stap \(currentIndex + 1) van \(steps.count): \(steps[min(currentIndex, steps.count - 1)])")
    }

    /// "Authenticator-code" breaks after the hyphen instead of before it. Short words such as "e-mail" stay whole.
    static func breakingAfterHyphen(_ title: String) -> String {
        title.replacing(/(\p{L}{6,})-/) { "\($0.1)-\u{200B}" }
    }

    private func line(isVisible: Bool, isDone: Bool) -> some View {
        Rectangle()
            .fill(isVisible ? (isDone ? Color.paveAccent : .hairline) : .clear)
            .frame(height: 2)
    }

    @ViewBuilder
    private func circle(index: Int) -> some View {
        let isReached = index <= currentIndex
        ZStack {
            Circle()
                .fill(isReached ? Color.paveAccent : .white)
                .overlay { Circle().strokeBorder(isReached ? Color.paveAccent : .hairline, lineWidth: 1) }
            if index < currentIndex {
                Image(.iconCheck)
                    .renderingMode(.template)
                    .resizable()
                    .paveIconFrame(13)
                    .foregroundStyle(.white)
            } else {
                Text("\(index + 1)")
                    .textStyle(.caption)
                    .foregroundStyle(isReached ? Color.white : .inkMuted)
            }
        }
        .frame(width: 24, height: 24)
    }
}

#Preview {
    VStack(spacing: 32) {
        AuthSteps(steps: ["E-mail", "Code uit e-mail", "Authenticator-code", "Nieuw wachtwoord"], currentIndex: 0)
        AuthSteps(steps: ["E-mail", "Code uit e-mail", "Authenticator-code", "Nieuw wachtwoord"], currentIndex: 2)
        AuthSteps(steps: ["E-mail", "Code uit e-mail", "Nieuw wachtwoord"], currentIndex: 2)
    }
    .padding(32)
    .background(Color.canvas)
}
