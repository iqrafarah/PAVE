import PAVECore
import SwiftUI

/// Step 2, "Documenten": how the card looks (logo and cover), and the files that prove it. Every document can be
/// opened, removed, or joined by another one.
struct VaultDocumentsStep: View {
    @Bindable var flow: VaultAddEvidenceModel
    @State private var logoSource: VaultFileSource?
    @State private var coverSource: VaultFileSource?
    @State private var documentSource: VaultFileSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VaultLookSection(
                logo: flow.logo.map { .upload($0) },
                cover: flow.cover.map { .upload($0) },
                wantsCover: Binding(get: { flow.wantsCover }, set: { flow.wantsCover = $0; flow.problem = nil }),
                title: flow.draft.title,
                category: flow.draft.category,
                onChooseLogo: { logoSource = $0 },
                onRemoveLogo: flow.removeLogo,
                onChooseCover: { coverSource = $0 },
                onRemoveCover: flow.removeCover
            )
            VaultDocumentsSection(count: flow.documents.count, canAdd: flow.canAddDocument, onChoose: { documentSource = $0 }) {
                ForEach(flow.documents, id: \.checksum) { document in
                    VaultFileRow(upload: document) { flow.remove(document) }
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: flow.documents)
        .vaultFilePicker(source: $logoSource, role: .logo) { flow.pick($0) }
        .vaultFilePicker(source: $coverSource, role: .cover) { flow.pick($0) }
        .vaultFilePicker(source: $documentSource, role: .document) { flow.pick($0) }
    }
}

#Preview {
    ScrollView {
        VaultDocumentsStep(flow: VaultAddEvidenceModel(vault: VaultModel(previewContents: .preview), category: .projects, folderID: nil))
            .padding(24)
    }
}
