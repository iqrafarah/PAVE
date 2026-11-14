import PAVECore
import SwiftUI

/// Evidence built up together in the chat: what Ayla has so far from the conversation and from the files, the fields
/// still missing, the files that go with it, and the way into the vault. Only the newest card can be used; older ones
/// show what was known then, and one whose item is in the vault says so.
struct AylaEvidenceConceptCard: View {
    let item: AylaReply.VaultItemProposal
    var analysis: AylaChatModel.EvidenceAnalysis?
    /// The files that go along, and which of them the user took out.
    var files: [VaultUpload] = []
    var excluded: Set<String> = []
    let isLast: Bool
    var isAdded = false
    var onToggleFile: (VaultUpload) -> Void = { _ in }
    /// Once it is in the vault: asking someone to confirm it.
    var onRequestConfirmation: (() -> Void)?
    let onAdd: () -> Void

    /// The documents completed with the chat, or only the chat while the files are still being read.
    private var proposal: VaultEvidenceProposal? {
        analysis?.first?.merged(with: item)
    }

    private var draft: VaultItemDraft {
        proposal?.applied(to: VaultItemDraft(category: item.category.category ?? .other)) ?? item.partialDraft
    }

    private var skills: [String] {
        proposal?.skills.map(\.name) ?? item.skills ?? []
    }

    private var rows: [(label: String, value: String?)] {
        [
            ("Soort", draft.category.singularTitle),
            ("Titel", draft.title.isEmpty ? nil : draft.title),
            ("Organisatie", draft.organisationName.isEmpty ? nil : [draft.organisationName, draft.organisationLocation].filter { !$0.isEmpty }.joined(separator: ", ")),
            ("Periode", draft.period),
            ("Beschrijving", draft.description.isEmpty ? nil : draft.description),
            ("Vaardigheden", skills.isEmpty ? nil : skills.joined(separator: ", ")),
        ]
    }

    private var isComplete: Bool {
        !draft.title.isEmpty && (!draft.organisationName.isEmpty || draft.period != nil)
    }

    private var fromFiles: String? {
        guard let analysis, !analysis.isReading, let first = analysis.first else { return nil }
        return AylaMessages.conceptFromFiles(logo: first.logoDocument != nil || first.logo != nil, cover: first.coverDocument != nil, items: analysis.proposals.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(isAdded ? .iconCheckBadgeSolid : .iconDocumentPlusSolid)
                    .renderingMode(.template)
                    .foregroundStyle(Color.paveAccent)
                    .paveIconFrame(22)
                    .accessibilityHidden(true)
                Text(isAdded ? AylaMessages.conceptAdded : isComplete ? AylaMessages.conceptReady : AylaMessages.conceptTitle)
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
            if let analysis, analysis.isReading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(AylaMessages.conceptReading)
                        .textStyle(.meta)
                        .foregroundStyle(Color.inkMuted)
                }
            } else if let fromFiles {
                VaultAylaNote(text: fromFiles)
            }
            if !files.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AylaMessages.conceptFiles)
                        .textStyle(.meta)
                        .foregroundStyle(Color.inkMuted)
                    FlowLayout(spacing: 6) {
                        ForEach(files, id: \.checksum) { file in
                            fileChip(file)
                        }
                    }
                }
            }
            if isAdded, let onRequestConfirmation {
                PaveSecondaryButton(title: AylaMessages.conceptRequestConfirmation, action: onRequestConfirmation)
            }
            if isLast, !isAdded {
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
        .animation(.easeOut(duration: 0.2), value: analysis?.isReading)
    }

    /// A file that goes along; on the newest card a tap leaves it out or takes it back.
    private func fileChip(_ file: VaultUpload) -> some View {
        let isOn = !excluded.contains(file.checksum)
        return Button { onToggleFile(file) } label: {
            HStack(spacing: 5) {
                Image(isOn ? .iconCheck : .iconPlus)
                    .renderingMode(.template)
                    .resizable()
                    .paveIconFrame(11)
                    .foregroundStyle(isOn ? Color.paveAccent : .inkMuted)
                Text(file.fileName)
                    .textStyle(.meta)
                    .foregroundStyle(isOn ? Color.ink : .inkMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .frame(maxWidth: 190)
            .fixedSize(horizontal: true, vertical: false)
            .background(isOn ? Color.paveSurfaceTint : Color.canvas, in: .rect(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
        }
        .buttonStyle(.pave)
        .disabled(!isLast || isAdded)
        .accessibilityLabel(file.fileName)
        .accessibilityValue(isOn ? "Gaat mee" : "Gaat niet mee")
        .accessibilityAddTraits(.isToggle)
    }
}

#Preview {
    VStack(spacing: 16) {
        AylaEvidenceConceptCard(item: .init(category: .internships, title: "Stage", organisationName: "LiveWall"), isLast: true) {}
        AylaEvidenceConceptCard(
            item: .init(category: .internships, title: "Eindstage front-end", organisationName: "LiveWall", organisationLocation: "Tilburg", startDate: "2025-02-01", endDate: "2025-07-01", description: "Je bouwde de front-end van drie campagnes in React.", skills: ["React", "Samenwerken", "Scrum"]),
            files: [VaultUpload(data: Data([1]), fileName: "verslag.pdf", mimeType: "application/pdf"), VaultUpload(data: Data([2]), fileName: "Foto 2026-11-13.jpeg", mimeType: "image/jpeg")],
            isLast: true
        ) {}
    }
    .padding(24)
    .background(Color.canvas)
}
