import PAVECore
import SwiftUI

/// Above Ayla's vacancies: what she searched for, and one row that says which of your data she used and lets you
/// choose that yourself. Nothing here is a guess: it is what the answer itself says it used.
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
        VStack(alignment: .leading, spacing: 10) {
            if let search {
                Text(AylaMessages.vacancySearchedFor(search))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onChooseData {
                Button(action: onChooseData) { row(action: hasChoice ? AylaMessages.vacancyChangeData : AylaMessages.vacancyChooseData) }
                    .buttonStyle(.pave)
                    .accessibilityHint("Je kiest uit je kluis; Ayla zoekt daarna opnieuw")
            } else {
                row(action: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(action: String?) -> some View {
        HStack(spacing: 10) {
            Image(.iconFolderSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(16)
                .foregroundStyle(Color.paveAccent)
                .accessibilityHidden(true)
            Text(usedText)
                .textStyle(.chip)
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Text(action)
                    .textStyle(.chip)
                    .foregroundStyle(Color.paveAccent)
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconHeight(10)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 14))
        .contentShape(.rect(cornerRadius: 14))
    }
}

#Preview {
    VacancySearchSummary(search: VacancySearch(what: "developer", where: "Eindhoven", also: "tester"), usedData: [], chosenCount: 2, onChooseData: {})
        .padding()
}
