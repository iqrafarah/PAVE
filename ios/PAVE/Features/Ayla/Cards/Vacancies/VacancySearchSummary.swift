import PAVECore
import SwiftUI

/// Above Ayla's vacancies: what she searched for, which of your data she used for it, and the way to choose that
/// yourself. Nothing here is a guess: it is what the answer itself says it used.
struct VacancySearchSummary: View {
    let search: VacancySearch?
    let usedData: [AylaVaultCategory]
    /// How many items you chose for this conversation; nil when Ayla uses everything she may see.
    let chosenCount: Int?
    /// Nil when the vault cannot be chosen from (yet).
    let onChooseData: (() -> Void)?

    private var usedNames: [String] { usedData.compactMap { $0.category?.title.lowercased() } }

    private var usedText: String {
        if let chosenCount, chosenCount > 0 { return AylaMessages.vacancyChosenData(chosenCount) }
        return usedNames.isEmpty ? AylaMessages.vacancyNoData : AylaMessages.usedVault(usedNames)
    }

    private var hasChoice: Bool { (chosenCount ?? 0) > 0 || !usedNames.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let search {
                Text(AylaMessages.vacancySearchedFor(search))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(.iconFolderSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(12)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
                Text(usedText)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if let onChooseData {
                Button(action: onChooseData) {
                    VacancyActionLabel(title: hasChoice ? AylaMessages.vacancyOtherData : AylaMessages.vacancyChooseData, symbol: "slider.horizontal.3")
                }
                .buttonStyle(.pave)
                .accessibilityHint("Je kiest uit je kluis; Ayla zoekt daarna opnieuw")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VacancySearchSummary(search: VacancySearch(what: "developer", where: "Eindhoven", also: "tester"), usedData: [], chosenCount: 2, onChooseData: {})
        .padding()
}
