import PAVECore
import SwiftUI

/// Step 2: with or without a cover. With one, the dashed area asks for a photo, which then shows as it will look.
struct VaultCoverPicker: View {
    @Bindable var flow: VaultAddEvidenceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var source: VaultFileSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                (Text(VaultMessages.coverTitle) + Text(" *").foregroundStyle(Color.brandGreen))
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 12) {
                    VaultCoverOption(title: VaultMessages.noCover, image: .vaultCoverNone, isSelected: !flow.wantsCover) {
                        choose(false)
                    }
                    VaultCoverOption(title: VaultMessages.withCover, image: .vaultCoverPhoto, isSelected: flow.wantsCover) {
                        choose(true)
                    }
                }
            }
            if flow.wantsCover {
                Group {
                    if let cover = flow.cover {
                        preview(cover)
                    } else {
                        VaultUploadZone(title: VaultMessages.uploadTitle, hint: VaultMessages.coverHint, sources: [.photos, .files]) {
                            source = $0
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy(duration: 0.35), value: flow.wantsCover)
        .animation(.snappy(duration: 0.3), value: flow.cover)
        .vaultFilePicker(source: $source, role: .cover) { flow.pick($0) }
    }

    private func choose(_ wantsCover: Bool) {
        guard flow.wantsCover != wantsCover else { return }
        PaveHaptics.selection()
        flow.wantsCover = wantsCover
        flow.problem = nil
    }

    private func preview(_ cover: VaultUpload) -> some View {
        VStack(spacing: 10) {
            if let image = UIImage(data: cover.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 194)
                    .clipShape(.rect(cornerRadius: 12))
                    .accessibilityLabel("Gekozen omslag")
            }
            VaultFileRow(upload: cover) { flow.removeCover() }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

#Preview {
    VaultCoverPicker(flow: VaultAddEvidenceModel(vault: VaultModel(previewContents: .preview), category: .projects, folderID: nil))
        .padding(24)
}
