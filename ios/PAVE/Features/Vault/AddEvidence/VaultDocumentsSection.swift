import SwiftUI

/// "Documenten": the files of the evidence and a low row to add another one, up to the maximum.
struct VaultDocumentsSection<Rows: View>: View {
    let count: Int
    let canAdd: Bool
    let onChoose: (VaultFileSource) -> Void
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(VaultMessages.documentsTitle)
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            if count == 0 {
                Text(VaultMessages.documentsEmpty)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            rows
            if canAdd {
                VaultUploadZone(
                    title: count == 0 ? VaultMessages.addDocument : VaultMessages.addAnotherDocument,
                    hint: VaultMessages.uploadHint,
                    sources: [.files, .photos],
                    isCompact: true,
                    onChoose: onChoose
                )
            }
        }
    }
}
