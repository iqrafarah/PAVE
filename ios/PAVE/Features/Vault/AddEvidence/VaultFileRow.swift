import PAVECore
import SwiftUI

/// A chosen file: a small picture of it, its name and size, and a cross to take it away again. Tapping it opens it.
struct VaultFileRow: View {
    let upload: VaultUpload
    let onRemove: () -> Void
    @State private var previewURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    VaultThumbnail(source: .upload(upload))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(upload.fileName)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(upload.summary)
                            .textStyle(.meta)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("\(upload.fileName), \(upload.summary)")
            .accessibilityHint("Tik om te bekijken")
            Button(action: onRemove) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("\(upload.fileName) weghalen")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
        .vaultQuickLook($previewURL)
    }

    private func open() {
        previewURL = VaultPreviewFile.url(for: upload.data, named: upload.fileName)
    }
}

#Preview {
    VaultFileRow(upload: VaultUpload(data: Data(count: 2_400_000), fileName: "LiveWall-eindstage-verslag.pdf", mimeType: "application/pdf")) {}
        .padding(24)
}
