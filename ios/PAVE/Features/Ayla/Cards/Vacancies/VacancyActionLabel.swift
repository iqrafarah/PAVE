import SwiftUI

/// The look of Bewaren, Vraag Ayla and the link to the whole vacancy: a capsule with an icon, filled when it is on.
struct VacancyActionLabel: View {
    let title: String
    let symbol: String
    var isOn = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .lineLimit(1)
        }
        .textStyle(.caption)
        .foregroundStyle(isOn ? Color.white : Color.paveAccent)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(isOn ? Color.paveAccentFill : Color.paveSurfaceTint, in: .capsule)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
