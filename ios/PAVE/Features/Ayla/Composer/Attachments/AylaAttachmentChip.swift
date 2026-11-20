import SwiftUI

/// A file added to a message: in the text field with a button to remove it, and above the message once sent.
struct AylaAttachmentChip: View {
    let name: String
    var onRemove: (() -> Void)?
    /// Above a sent message: smaller, several on a line.
    var isCompact = false

    var body: some View {
        HStack(spacing: isCompact ? 4 : 6) {
            Image(.iconPaperclip)
                .renderingMode(.template)
                .resizable()
                .paveIconFrame(isCompact ? 12 : 16)
                .foregroundStyle(Color.paveAccent)
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
                        .paveIconFrame(9)
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, height: 44)
                        .contentShape(.rect)
                        // 44 high to tap, without making the chip taller.
                        .padding(.vertical, -6)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("\(name) weghalen")
            }
        }
        .padding(.leading, isCompact ? 8 : 10)
        .padding(.trailing, onRemove == nil ? (isCompact ? 9 : 12) : 0)
        .frame(height: isCompact ? 26 : 32)
        .frame(maxWidth: isCompact ? 190 : 260, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: isCompact ? 9 : 12))
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
