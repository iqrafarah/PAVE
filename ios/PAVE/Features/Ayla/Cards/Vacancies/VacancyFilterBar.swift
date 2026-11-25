import PAVECore
import SwiftUI

/// Above the vacancies: how many are shown, the order, and the filters.
struct VacancyFilterBar: View {
    @Binding var filter: VacancyFilter
    let shown: Int
    let total: Int
    let onShowFilters: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                count.fixedSize()
                Spacer(minLength: 4)
                chips
            }
            VStack(alignment: .leading, spacing: 8) {
                count
                HStack(spacing: 8) { chips }
            }
        }
    }

    private var count: some View {
        Text(AylaMessages.vacancyShown(shown, of: total))
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .monospacedDigit()
    }

    @ViewBuilder
    private var chips: some View {
            Menu {
                Picker(AylaMessages.vacancyOrderAsFound, selection: $filter.order) {
                    Text(AylaMessages.vacancyOrderAsFound).tag(VacancyFilter.Order.asFound)
                    Text(AylaMessages.vacancyOrderBestMatch).tag(VacancyFilter.Order.bestMatch)
                }
            } label: {
                chip(icon: .iconArrowsRightLeftSolid, title: filter.order == .bestMatch ? AylaMessages.vacancyOrderBestMatch : AylaMessages.vacancyOrderAsFound, isOn: filter.order == .bestMatch, rotatesIcon: true)
            }
            Button(action: onShowFilters) {
                chip(icon: .iconFunnelSolid, title: filter.activeCount == 0 ? AylaMessages.vacancyFilter : AylaMessages.vacancyFilterCount(filter.activeCount), isOn: filter.activeCount > 0)
            }
            .buttonStyle(.pave)
    }

    private func chip(icon: ImageResource, title: String, isOn: Bool, rotatesIcon: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(14)
                .rotationEffect(.degrees(rotatesIcon ? 90 : 0))
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.chip)
                .lineLimit(1)
        }
        .foregroundStyle(isOn ? Color.white : Color.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
        .frame(minHeight: 44)
        .contentShape(.capsule)
    }
}
