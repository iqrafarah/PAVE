import PAVECore
import SwiftUI

/// A skill that fits or that you still miss, with the line of the vacancy it comes from, so you can check it. A
/// missing skill can ask Ayla how to get it.
struct VacancyRequirementRow: View {
    let link: Vacancy.RequirementLink
    let isGap: Bool
    var onAsk: (() -> Void)?

    var body: some View {
        if let onAsk {
            Button(action: onAsk) { row }
                .buttonStyle(.pave)
                .accessibilityHint("Vraagt Ayla hoe je dit kunt halen")
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isGap ? "plus.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isGap ? Color.inkMuted : Color.paveAccent)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.skill)
                    .textStyle(.gapChip)
                    .foregroundStyle(isGap ? Color.ink : Color.paveAccent)
                Text("“\(link.requirement)”")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            if onAsk != nil {
                Image(.iconArrowRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconHeight(9)
                    .foregroundStyle(Color.paveAccent)
                    .padding(.top, 5)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(isGap ? Color.panel : Color.paveSurfaceTint, in: .rect(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(isGap ? Color.cardBorder : .clear, lineWidth: 1) }
        .contentShape(.rect(cornerRadius: 9))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.skill), uit de vacature: \(link.requirement)")
    }
}
