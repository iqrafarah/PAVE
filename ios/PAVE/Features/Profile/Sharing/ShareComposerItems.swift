import PAVECore
import SwiftUI

/// The evidence to choose from, per kind, with its status and whether this recipient needs it.
struct ShareComposerItems: View {
    let items: [VaultItem]
    let template: ShareTemplate
    @Binding var chosen: Set<String>
    /// For a saved profile: chosen evidence can be shown briefly. Nil in the composer.
    var brief: Binding<Set<String>>?

    private var groups: [(category: VaultCategory, items: [VaultItem])] {
        VaultCategory.allCases.compactMap { category in
            let inIt = items.filter { $0.category == category && $0.status != .rejected }
            return inIt.isEmpty ? nil : (category, inIt)
        }
    }

    var body: some View {
        ForEach(groups, id: \.category) { group in
            SharePanel(title: group.category.title) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    row(item, isNeeded: template.categories.contains(item.category))
                    if index < group.items.count - 1 { ShareRowDivider(inset: 46) }
                }
            }
        }
    }

    private func row(_ item: VaultItem, isNeeded: Bool) -> some View {
        let isOn = chosen.contains(item.id)
        return Button {
            PaveHaptics.selection()
            if isOn { chosen.remove(item.id) } else { chosen.insert(item.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PaveCheckbox(isOn: isOn, size: 20).padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(isOn ? Color.ink : Color.inkMuted)
                        .multilineTextAlignment(.leading)
                    if let detail = [item.organisationName, item.period].compactMap({ $0 }).filter({ !$0.isEmpty }).joined(separator: " · ").nilIfEmpty {
                        Text(detail)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    if !isNeeded, isOn {
                        Text(SharingMessages.notNeeded)
                            .textStyle(.caption)
                            .foregroundStyle(Color.warning)
                    }
                    VaultStatusBadge(item: item)
                        .padding(.leading, -4)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .overlay(alignment: .bottomTrailing) {
            if let brief, isOn {
                ShareDetailPicker(isBrief: Binding(
                    get: { brief.wrappedValue.contains(item.id) },
                    set: { if $0 { brief.wrappedValue.insert(item.id) } else { brief.wrappedValue.remove(item.id) } }
                ))
                .padding(.trailing, 14)
                .padding(.bottom, 12)
            }
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
