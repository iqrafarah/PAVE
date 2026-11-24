import PAVECore
import SwiftUI

/// One piece of evidence while choosing what goes on the CV: on or off, why Ayla proposes that, and how sure it is.
struct ApplicationContentRow: View {
    let entry: CVEntry
    let item: VaultItem?
    let choice: ApplicationProposal.Choice?
    let onToggle: (Bool) -> Void

    private var detail: String {
        [entry.organisation, entry.period].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The reason belongs to the proposal; once the user turned it round, it no longer says why.
    private var reason: String? {
        guard let choice, choice.isOn == entry.isVisible else { return nil }
        return ApplyMessages.reason(choice.reason)
    }

    private var fits: Bool {
        if case .fits = choice?.reason, entry.isVisible { return true }
        return false
    }

    var body: some View {
        Button {
            PaveHaptics.selection()
            onToggle(!entry.isVisible)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PaveCheckbox(isOn: entry.isVisible, size: 20)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(entry.isVisible ? Color.ink : Color.inkMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !detail.isEmpty {
                        Text(detail)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let reason {
                        Text(reason)
                            .textStyle(.caption)
                            .foregroundStyle(fits ? Color.paveAccent : Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let item, item.aylaAllowedAt == nil, entry.isVisible {
                        Text(ApplyMessages.aylaMayNotSee)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Under the text, so a long title has the whole width.
                    if let item {
                        VaultStatusBadge(item: item)
                            .padding(.leading, -4)
                            .padding(.top, 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(entry.isVisible ? .isSelected : [])
    }
}
