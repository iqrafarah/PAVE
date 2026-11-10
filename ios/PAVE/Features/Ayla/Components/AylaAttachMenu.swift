import SwiftUI

/// What the plus button adds to a message (Figma "iPhone 16 & 17 Pro Max - 2", in the current style).
/// It grows out of the text field and covers its left side. Items from the vault and plans can be added
/// once those exist; until then the rows say why not.
struct AylaAttachMenu: View {
    let onAddFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11.5) {
            AylaAttachMenuRow(icon: .iconFolder, title: "Item toevoegen", note: "Je kluis is nog leeg")
            AylaAttachMenuRow(icon: .iconMap, title: "Plan toevoegen", note: "Je hebt nog geen plan")
            AylaAttachMenuRow(icon: .iconPaperclip, title: "Bestand toevoegen", action: onAddFile)
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
    AylaAttachMenu(onAddFile: {})
        .padding()
        .background(Color.canvas)
}
