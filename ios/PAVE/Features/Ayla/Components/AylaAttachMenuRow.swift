import SwiftUI

/// One choice in the plus menu: an icon in a circle and what it adds. Without an action it explains why it cannot be used yet.
struct AylaAttachMenuRow: View {
    let icon: ImageResource
    let title: String
    var note: String?
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                Image(icon)
                    .renderingMode(.template)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .disabled(action == nil)
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
