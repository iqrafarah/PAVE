import PAVECore
import SwiftUI

/// Evidence built up together in the chat: the fields Ayla has so far, the ones still missing, and the way into the
/// vault with it. Only the newest card can be used; older ones show what was known then.
struct AylaEvidenceConceptCard: View {
    let item: AylaReply.VaultItemProposal
    let isLast: Bool
    let onAdd: () -> Void

    private var draft: VaultItemDraft { item.partialDraft }

    private var rows: [(label: String, value: String?)] {
        [
            ("Soort", item.category.category?.singularTitle),
            ("Titel", draft.title.isEmpty ? nil : draft.title),
            ("Organisatie", draft.organisationName.isEmpty ? nil : [draft.organisationName, draft.organisationLocation].filter { !$0.isEmpty }.joined(separator: ", ")),
            ("Periode", draft.period),
            ("Beschrijving", draft.description.isEmpty ? nil : draft.description),
            ("Vaardigheden", (item.skills ?? []).isEmpty ? nil : item.skills?.joined(separator: ", ")),
        ]
    }

    private var isComplete: Bool {
        !draft.title.isEmpty && (!draft.organisationName.isEmpty || draft.period != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(.iconDocumentPlusSolid)
                    .renderingMode(.template)
                    .foregroundStyle(Color.paveAccent)
                    .paveIconFrame(22)
                    .accessibilityHidden(true)
                Text(isComplete ? AylaMessages.conceptReady : AylaMessages.conceptTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.label) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label)
                            .textStyle(.meta)
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 96, alignment: .leading)
                        Text(row.value ?? AylaMessages.conceptUnknown)
                            .textStyle(.caption)
                            .foregroundStyle(row.value == nil ? Color.inkMuted.opacity(0.7) : .ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if isLast {
                if !isComplete {
                    Text(AylaMessages.conceptHint)
                        .textStyle(.meta)
                        .foregroundStyle(Color.inkMuted)
                }
                PavePrimaryButton(title: AylaMessages.conceptAdd, action: onAdd)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}

#Preview {
    VStack(spacing: 16) {
        AylaEvidenceConceptCard(item: .init(category: .internships, title: "Stage", organisationName: "LiveWall"), isLast: true) {}
        AylaEvidenceConceptCard(
            item: .init(category: .internships, title: "Eindstage front-end", organisationName: "LiveWall", organisationLocation: "Tilburg", startDate: "2025-02-01", endDate: "2025-07-01", description: "Je bouwde de front-end van drie campagnes in React.", skills: ["React", "Samenwerken", "Scrum"]),
            isLast: true
        ) {}
    }
    .padding(24)
    .background(Color.canvas)
}
