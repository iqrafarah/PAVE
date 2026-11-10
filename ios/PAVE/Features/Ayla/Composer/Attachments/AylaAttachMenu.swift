import SwiftUI
import UniformTypeIdentifiers

/// What the plus button adds to a message (Figma "iPhone 16 & 17 Pro Max - 2", in the current style).
/// It grows out of the text field and covers its left side. Items from the vault and plans can be added
/// once those exist; until then the rows say why not. "Plakken" only shows while a photo or pdf is on the clipboard.
struct AylaAttachMenu: View {
    let onAddFile: () -> Void
    var onScan: (() -> Void)?
    var onPaste: (() -> Void)?

    @State private var canPaste = Self.clipboardHasFile

    /// Asking whether there is something does not trigger the "allow paste" question; only reading it does.
    private static var clipboardHasFile: Bool {
        UIPasteboard.general.hasImages || UIPasteboard.general.contains(pasteboardTypes: [UTType.pdf.identifier])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4.5) {
            AylaAttachMenuRow(icon: .iconFolder, title: "Item toevoegen", note: "Je kluis is nog leeg")
            AylaAttachMenuRow(icon: .iconMap, title: "Plan toevoegen", note: "Je hebt nog geen plan")
            AylaAttachMenuRow(icon: .iconPaperclip, title: "Bestand toevoegen", action: onAddFile)
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
    AylaAttachMenu(onAddFile: {}, onScan: {}, onPaste: {})
        .padding()
        .background(Color.canvas)
}
