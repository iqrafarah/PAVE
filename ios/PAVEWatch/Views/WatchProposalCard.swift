import PAVECore
import SwiftUI

/// Ayla's proposal under her answer, such as putting a stage in the vault, with Ja and Nee. Nothing happens without Ja.
struct WatchProposalCard: View {
    let proposal: WatchAylaModel.Proposal
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Voorstel van Ayla")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brandGreen)
            Text(proposal.draft.title)
                .font(.footnote.weight(.medium))
            Text(details)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            switch proposal.state {
            case .asking:
                if proposal.action.isOpen() {
                    HStack(spacing: 6) {
                        Button("Nee") { onAnswer(false) }
                        Button("Ja") { onAnswer(true) }
                            .tint(.brandGreen)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Dit voorstel is verlopen. Vraag het Ayla opnieuw.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .saving:
                ProgressView()
            case .done:
                status("In je kluis gezet, nog niet bevestigd", icon: .watchIconCheck)
            case .declined:
                status("Niet toegevoegd", icon: .watchIconXMark)
            case .failed:
                Text("Dat lukte niet. Probeer het op je iPhone.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandGreen.opacity(0.18), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    /// "Stages · LiveWall, Tilburg": the category and where, so you know what Ja does.
    private var details: String {
        let place = [proposal.draft.organisationName, proposal.draft.organisationLocation]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return place.isEmpty ? proposal.draft.category.title : "\(proposal.draft.category.title) · \(place)"
    }

    private func status(_ text: String, icon: ImageResource) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(icon).renderingMode(.template)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
