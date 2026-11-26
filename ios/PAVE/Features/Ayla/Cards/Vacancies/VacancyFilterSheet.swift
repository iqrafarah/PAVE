import PAVECore
import SwiftUI

/// Narrowing down the vacancies: place, hours, and a company that hires directly or an agency. Shows how many are left
/// before you close it.
struct VacancyFilterSheet: View {
    @Binding var filter: VacancyFilter
    let vacancies: [Vacancy]
    @Environment(\.dismiss) private var dismiss

    private var cities: [String] { VacancyFilter.cities(in: vacancies) }
    private var remaining: Int { filter.apply(to: vacancies).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if cities.count > 1 {
                        group(AylaMessages.vacancyFilterPlace) {
                            choice(AylaMessages.vacancyFilterAll, isOn: filter.city == nil) { filter.city = nil }
                            ForEach(cities, id: \.self) { city in
                                choice(city, isOn: filter.city == city) { filter.city = city }
                            }
                        }
                    }
                    group(AylaMessages.vacancyFilterHours) {
                        choice(AylaMessages.vacancyFilterAll, isOn: filter.employment == nil) { filter.employment = nil }
                        choice(AylaMessages.vacancyFullTime, isOn: filter.employment == .fullTime) { filter.employment = .fullTime }
                        choice(AylaMessages.vacancyPartTime, isOn: filter.employment == .partTime) { filter.employment = .partTime }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        group(AylaMessages.vacancyFilterEmployer) {
                            choice(AylaMessages.vacancyFilterAll, isOn: filter.employer == .any) { filter.employer = .any }
                            choice(AylaMessages.vacancyEmployerDirect, isOn: filter.employer == .direct) { filter.employer = .direct }
                            choice(AylaMessages.vacancyEmployerAgency, isOn: filter.employer == .agency) { filter.employer = .agency }
                        }
                        Text(AylaMessages.vacancyEmployerHint)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .padding(.leading, 8)
                    }
                }
                .padding(20)
            }
            .background(Color.canvas)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    PavePrimaryButton(title: remaining == 0 ? AylaMessages.vacancyFilterNone : AylaMessages.vacancyFilterShow(remaining)) { dismiss() }
                        .disabled(remaining == 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.canvas)
            }
            .navigationTitle(AylaMessages.vacancyFilter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AylaMessages.vacancyFilterClear) {
                        filter = VacancyFilter(order: filter.order)
                    }
                    .disabled(filter.activeCount == 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .padding(.leading, 8)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: 8) { content() }
        }
    }

    private func choice(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            PaveHaptics.selection()
            action()
        } label: {
            Text(title)
                .textStyle(.chip)
                .foregroundStyle(isOn ? Color.white : Color.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
                .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
                .frame(minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
