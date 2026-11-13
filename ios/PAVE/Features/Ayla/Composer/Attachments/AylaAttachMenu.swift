import SwiftUI
import UniformTypeIdentifiers

/// What the plus button adds to a message (Figma "iPhone 16 & 17 Pro Max - 2", in the current style).
/// It grows out of the text field and covers its left side. An item from the vault becomes what the conversation is
/// about; plans can be added once they exist, until then the row says why not. "Plakken" only shows while a photo or
/// pdf is on the clipboard.
struct AylaAttachMenu: View {
    let onAddFile: () -> Void
    var onPhoto: (() -> Void)?
    /// Nil while the vault is empty or not there: the row then says so.
    var onPickItem: (() -> Void)?
    var onScan: (() -> Void)?
    var onPaste: (() -> Void)?

    @State private var canPaste = Self.clipboardHasFile

    /// Asking whether there is something does not trigger the "allow paste" question; only reading it does.
    private static var clipboardHasFile: Bool {
        UIPasteboard.general.hasImages || UIPasteboard.general.contains(pasteboardTypes: [UTType.pdf.identifier])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4.5) {
            if let onPickItem {
                AylaAttachMenuRow(icon: .iconFolder, title: AylaMessages.attachItem, action: onPickItem)
            } else {
                AylaAttachMenuRow(icon: .iconFolder, title: AylaMessages.attachItem, note: AylaMessages.vaultEmpty)
            }
            AylaAttachMenuRow(icon: .iconMap, title: "Plan toevoegen", note: "Je hebt nog geen plan")
            AylaAttachMenuRow(icon: .iconPaperclip, title: "Bestand toevoegen", action: onAddFile)
            if let onPhoto {
                AylaAttachMenuRow(icon: .iconPhotoSolid, title: "Foto toevoegen", action: onPhoto)
            }
            if let onScan {
                AylaAttachMenuRow(icon: .iconCamera, title: "Document scannen", action: onScan)
            }
            if canPaste, let onPaste {
                AylaAttachMenuRow(icon: .iconClipboard, title: "Plakken", note: "Foto of pdf van je klembord", action: onPaste)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 21)
        .frame(width: 255, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 25))
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canPaste = Self.clipboardHasFile
        }
    }
}

#Preview {
    AylaAttachMenu(onAddFile: {}, onPhoto: {}, onPickItem: {}, onScan: {}, onPaste: {})
        .padding()
        .background(Color.canvas)
}
