import SwiftUI
import UniformTypeIdentifiers

/// What the plus button adds to a message (Figma "iPhone 16 & 17 Pro Max - 2", in the current style).
/// It grows out of the text field and covers its left side. Items from the vault and plans can be added
/// once those exist; until then the rows say why not.
struct AylaAttachMenu: View {
    let onAddFile: () -> Void
    var onScan: (() -> Void)?
    var onPaste: (([NSItemProvider]) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 11.5) {
            AylaAttachMenuRow(icon: .iconFolder, title: "Item toevoegen", note: "Je kluis is nog leeg")
            AylaAttachMenuRow(icon: .iconMap, title: "Plan toevoegen", note: "Je hebt nog geen plan")
            AylaAttachMenuRow(icon: .iconPaperclip, title: "Bestand toevoegen", action: onAddFile)
            if let onScan {
                AylaAttachMenuRow(symbol: "doc.viewfinder.fill", title: "Document scannen", action: onScan)
            }
            if let onPaste {
                // The system's own paste button: no "Allow paste?" question, because you tapped it yourself.
                PasteButton(supportedContentTypes: [.pdf, .image]) { providers in
                    onPaste(providers)
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .tint(.brandGreen)
                .padding(.top, 2)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 21)
        .frame(width: 255, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 25))
    }
}

#Preview {
    AylaAttachMenu(onAddFile: {}, onScan: {}, onPaste: { _ in })
        .padding()
        .background(Color.canvas)
}
