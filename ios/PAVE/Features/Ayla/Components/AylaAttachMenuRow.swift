import SwiftUI

/// One choice in the plus menu: an icon in a circle and what it adds. Without an action it explains why it cannot be used yet.
struct AylaAttachMenuRow: View {
    private let image: Image
    let title: String
    var note: String?
    var action: (() -> Void)?

    init(icon: ImageResource, title: String, note: String? = nil, action: (() -> Void)? = nil) {
        image = Image(icon).renderingMode(.template)
        self.title = title
        self.note = note
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.ink)
                    .frame(width: 37, height: 37)
                    .background(Color.white.opacity(0.7), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .textStyle(.menuItem)
                        .foregroundStyle(Color.ink)
                    if let note {
                        Text(note)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .disabled(action == nil)
        // What cannot be used yet looks it, so a tap that does nothing is no surprise.
        .opacity(action == nil ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 11.5) {
        AylaAttachMenuRow(icon: .iconFolder, title: "Item toevoegen", note: "Je kluis is nog leeg")
        AylaAttachMenuRow(icon: .iconPaperclip, title: "Bestand toevoegen", action: {})
    }
    .padding()
}
