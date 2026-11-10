import SwiftUI

/// A file added to a message: in the text field with a button to remove it, and above the message once sent.
struct AylaAttachmentChip: View {
    let name: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(.iconPaperclip)
                .renderingMode(.template)
                .foregroundStyle(Color.brandGreen)
                .accessibilityHidden(true)
            Text(name)
                .textStyle(.meta)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            if let onRemove {
                Button(action: onRemove) {
                    Image(.iconPlus)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 9, height: 9)
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("\(name) weghalen")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, onRemove == nil ? 12 : 0)
        .frame(height: 32)
        .frame(maxWidth: 260, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bijlage \(name)")
    }
}

#Preview {
    VStack(alignment: .trailing) {
        AylaAttachmentChip(name: "cv-daaf-heijnekamp-2026-definitief.pdf", onRemove: {})
        AylaAttachmentChip(name: "certificaat.jpg")
    }
    .padding()
}
