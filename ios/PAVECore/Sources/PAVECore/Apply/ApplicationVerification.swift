import Foundation

/// Which entries on a CV may carry the tick of verified evidence. An entry earns it only while its piece of evidence
/// is verified in the vault and the entry still says what was verified: its title, organisation and period. Change
/// one of those on the CV and the tick goes, as it does in the vault. What was done there, in the user's or Ayla's
/// words, is not what was verified and may differ.
public enum ApplicationVerification {
    public static func isVerified(_ entry: CVEntry, items: [VaultItem]) -> Bool {
        guard let item = items.first(where: { $0.id == entry.sourceItemID }), item.status == .verified, item.archivedAt == nil else { return false }
        return entry.title == item.title
            && entry.organisation == ApplicationBuilder.organisation(item)
            && entry.period == (item.period ?? "")
    }

    /// Sets the tick on every entry from what the vault says now.
    public static func mark(_ draft: inout ApplicationDraft, items: [VaultItem]) {
        for section in draft.cv.sections.indices {
            for index in draft.cv.sections[section].entries.indices {
                let verified = isVerified(draft.cv.sections[section].entries[index], items: items)
                if draft.cv.sections[section].entries[index].isVerified != verified {
                    draft.cv.sections[section].entries[index].isVerified = verified
                }
            }
        }
    }

    /// A tick shows somewhere on the CV, so the page needs the line that says what it means.
    public static func showsTick(_ draft: ApplicationDraft) -> Bool {
        draft.marksVerified && draft.cv.visibleSections.contains { $0.entries.contains { $0.isVisible && $0.isVerified } }
    }
}
