import PAVECore
import SwiftUI

/// A file of an item in the vault: its first page or the photo, and its name. Tapping it opens it with QuickLook.
struct VaultFileTile: View {
    let file: VaultItem.File
    @Environment(VaultModel.self) private var model
    @State private var previewURL: URL?
    @State private var isOpening = false
    @State private var failed = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                VaultThumbnail(source: .file(file), cornerRadius: 10)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay {
                        if isOpening {
                            ProgressView()
                                .padding(10)
                                .glassEffect(.regular, in: .circle)
                        }
                    }
                Text(file.name)
                    .textStyle(.meta)
                    .foregroundStyle(failed ? Color.critical : .ink)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .disabled(isOpening)
        .vaultQuickLook($previewURL)
        .accessibilityLabel(file.name)
        .accessibilityHint(failed ? "Openen lukte niet. Tik om het opnieuw te proberen." : "Tik om te openen")
    }

    private func open() {
        isOpening = true
        failed = false
        Task {
            defer { isOpening = false }
            guard let data = await model.data(of: file), let url = VaultPreviewFile.url(for: data, named: file.name) else {
                failed = true
                PaveHaptics.error()
                return
            }
            previewURL = url
        }
    }
}
