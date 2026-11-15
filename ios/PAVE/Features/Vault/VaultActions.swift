import PAVECore

/// What a page of the vault asks the vault screen to do: the sheets and questions live there, once, for every page.
struct VaultActions {
    let open: (VaultItem) -> Void
    let edit: (VaultItem) -> Void
    let requestConfirmation: (VaultItem) -> Void
    let delete: (VaultItem) -> Void
    /// New evidence, in this folder when one is open.
    let add: (VaultFolder?) -> Void
    /// Scanning a document straight into new evidence, which Ayla then fills in (the Camera Control button).
    var scan: (VaultFolder?) -> Void = { _ in }
    let newFolder: () -> Void
    let openFolder: (VaultFolder) -> Void
    let editFolder: (VaultFolder) -> Void
    let deleteFolder: (VaultFolder) -> Void
}
