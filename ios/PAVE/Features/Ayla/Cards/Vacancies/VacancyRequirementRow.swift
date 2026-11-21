import PAVECore
import SwiftUI

/// A skill that fits or that you still miss, with the line of the vacancy it comes from. A missing skill can ask
/// Ayla how to get it.
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isGap ? "plus" : "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isGap ? Color.inkMuted : Color.white)
                .frame(width: 22, height: 22)
                .background(isGap ? Color.paveSurfaceTint : Color.paveAccentFill, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(link.skill)
                    .textStyle(.gapChip)
                    .foregroundStyle(Color.ink)
                Text("“\(link.requirement)”")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            if onAsk != nil {
                Image(.iconArrowRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconHeight(9)
                    .foregroundStyle(Color.paveAccent)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.skill), uit de vacature: \(link.requirement)")
    }
}
