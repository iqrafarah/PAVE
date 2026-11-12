import PAVECore
import SwiftUI

/// A file that is already in the vault, while changing an item: its picture, name and kind, a tap to open it and a
/// cross to remove it when you save.
struct VaultRemoteFileRow: View {
    let file: VaultItem.File
    let onRemove: () -> Void
    @Environment(VaultModel.self) private var model
    @State private var previewURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    VaultThumbnail(source: .file(file))
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.name)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(VaultUpload.kind(of: file.mimeType))
                            .textStyle(.meta)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(file.name)
            .accessibilityHint("Tik om te bekijken")
            Button(action: onRemove) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(12)
                    .foregroundStyle(Color.inkMuted)
                    .paveIconFrame(44)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("\(file.name) weghalen")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
        .vaultQuickLook($previewURL)
    }

    private func open() {
        Task {
            guard let data = await model.data(of: file) else { return }
            previewURL = VaultPreviewFile.url(for: data, named: file.name)
        }
    }
}
