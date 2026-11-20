import PAVECore

/// A file added to the chat: the text Ayla reads, and the file itself when the vault can keep it, so "Ja" to adding
/// evidence takes the file along. The file never goes to Ayla's chat function.
struct AylaChatFile {
    let attachment: AylaAttachment
    let upload: VaultUpload?
}
