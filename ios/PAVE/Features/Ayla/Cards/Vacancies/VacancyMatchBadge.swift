import SwiftUI

/// How well a vacancy matches, as a small ring and a percentage. An estimate, and VoiceOver says so.
struct VacancyMatchBadge: View {
    let percent: Int

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.paveAccent.opacity(0.18), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(Color.paveAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 16, height: 16)
            Text(AylaMessages.vacancyMatch(percent))
                .textStyle(.chip)
                .foregroundStyle(Color.paveAccent)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(Color.panel.opacity(0.9), in: .capsule)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AylaMessages.vacancyMatch(percent))
        .accessibilityHint(AylaMessages.vacancyMatchHint)
    }
}

#Preview {
    VacancyMatchBadge(percent: 67)
        .padding()
        .background(Color.cardTintRose)
}
