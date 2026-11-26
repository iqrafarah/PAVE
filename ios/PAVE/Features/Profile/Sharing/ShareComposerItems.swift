import PAVECore
import SwiftUI

/// The evidence to choose from, per kind, with its status and whether this recipient needs it.
struct ShareComposerItems: View {
    let items: [VaultItem]
    let template: ShareTemplate
    @Binding var chosen: Set<String>
    /// For a saved profile: chosen evidence can be shown briefly. Nil in the composer.
    var brief: Binding<Set<String>>?
    /// Evidence whose files go along; nil where files cannot be chosen.
    var files: Binding<Set<String>>?
    /// Single files turned off, of evidence whose files go along; nil where that cannot be chosen.
    var hidden: Binding<Set<String>>?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openDestination) private var openDestination

    private var groups: [(category: VaultCategory, items: [VaultItem])] {
        VaultCategory.allCases.compactMap { category in
            let inIt = items.filter { $0.category == category && $0.status != .rejected }
            return inIt.isEmpty ? nil : (category, inIt)
        }
    }

    var body: some View {
        if groups.isEmpty {
            VStack(spacing: 16) {
                PaveEmptyState(icon: .iconFolder, title: SharingMessages.vaultEmptyTitle, message: SharingMessages.vaultEmpty)
                if let openDestination {
                    PaveSecondaryButton(title: SharingMessages.toVault) {
                        dismiss()
                        openDestination(.vault)
                    }
                    .frame(maxWidth: 260)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        ForEach(groups, id: \.category) { group in
            SharePanel(title: group.category.title) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    row(item, isNeeded: template.categories.contains(item.category))
                    if index < group.items.count - 1 { ShareRowDivider(inset: 46) }
                }
            }
        }
    }

    /// The row, and under it, outside its button, whether the file goes along.
    private func row(_ item: VaultItem, isNeeded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            choice(item, isNeeded: isNeeded)
            if let files, chosen.contains(item.id), ShareFiles.hasDocument(item) {
                VStack(alignment: .leading, spacing: 0) {
                    fileChip(item, files: files)
                    // More than one file: each can stay behind on its own.
                    if let hidden, files.wrappedValue.contains(item.id), ShareFiles.documents(of: item).count > 1 {
                        ForEach(ShareFiles.documents(of: item)) { file in
                            fileRow(file, of: item, files: files, hidden: hidden)
                        }
                    }
                }
                .padding(.leading, 46)
                .padding(.trailing, 14)
                .padding(.bottom, 8)
                .padding(.top, -6)
            }
        }
    }

    private func choice(_ item: VaultItem, isNeeded: Bool) -> some View {
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

    /// One file of evidence with several: on unless turned off. Turning the last one off turns the files of this
    /// evidence off altogether.
    private func fileRow(_ file: VaultItem.File, of item: VaultItem, files: Binding<Set<String>>, hidden: Binding<Set<String>>) -> some View {
        let isOn = !hidden.wrappedValue.contains(file.id)
        return Button {
            PaveHaptics.selection()
            if isOn {
                hidden.wrappedValue.insert(file.id)
                if !ShareFiles.sharesDocument(item, hidden: hidden.wrappedValue) {
                    files.wrappedValue.remove(item.id)
                    ShareFiles.documents(of: item).forEach { hidden.wrappedValue.remove($0.id) }
                }
            } else {
                hidden.wrappedValue.remove(file.id)
            }
        } label: {
            HStack(spacing: 8) {
                PaveCheckbox(isOn: isOn, size: 16)
                Text(file.name)
                    .textStyle(.caption)
                    .foregroundStyle(isOn ? Color.ink : Color.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(SharingMessages.fileGoes(file.name))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// The file of this evidence goes along, so the recipient can open it; on by default.
    private func fileChip(_ item: VaultItem, files: Binding<Set<String>>) -> some View {
        let isOn = files.wrappedValue.contains(item.id)
        return Button {
            PaveHaptics.selection()
            if isOn { files.wrappedValue.remove(item.id) } else { files.wrappedValue.insert(item.id) }
        } label: {
            HStack(spacing: 6) {
                PaveCheckbox(isOn: isOn, size: 16)
                Text(SharingMessages.withFile(isOn ? ShareFiles.documents(of: item, hidden: hidden?.wrappedValue ?? []).count : ShareFiles.documents(of: item).count))
                    .textStyle(.caption)
                    .foregroundStyle(isOn ? Color.ink : Color.inkMuted)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Array {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
