import SwiftUI

/// Two or three vacancies picked: one button to compare them, and a way to start over.
struct VacancyCompareBar: View {
    let count: Int
    let onCompare: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if count >= 2 {
                PavePrimaryButton(title: AylaMessages.vacancyCompareButton(count), action: onCompare)
            } else {
                Text(AylaMessages.vacancyCompareHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            Button(action: onClear) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(12)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Color.panel, in: .circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Niets meer vergelijken")
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    VacancyCompareBar(count: 2, onCompare: {}, onClear: {})
        .padding()
        .background(Color.canvas)
}
