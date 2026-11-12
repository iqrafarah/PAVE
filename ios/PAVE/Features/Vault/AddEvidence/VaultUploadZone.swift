import SwiftUI

/// The dashed area with the cloud: tap it and choose a file or a photo.
struct VaultUploadZone: View {
    let title: String
    var hint: String?
    let sources: [VaultFileSource]
    var height: CGFloat = 194
    /// One low row instead of the big area, for adding another file.
    var isCompact = false
    let onChoose: (VaultFileSource) -> Void

    var body: some View {
        Menu {
            ForEach(sources) { source in
                Button { onChoose(source) } label: {
                    switch source {
                    case .files: Label { Text("Kies een bestand") } icon: { Image(.iconDocumentSolid) }
                    case .photos: Label { Text("Kies een foto") } icon: { Image(.iconPhotoSolid) }
                    }
                }
            }
        } label: {
            if isCompact { compactLabel } else { largeLabel }
        }
        .menuStyle(.button)
        .buttonStyle(.pave)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }

    private var compactLabel: some View {
        HStack(spacing: 12) {
            Image(.iconCloudArrowUpSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.paveAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                if let hint {
                    Text(hint)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Color.paveDropZone, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.paveFocusRing, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        .contentShape(.rect(cornerRadius: 12))
    }

    private var largeLabel: some View {
            VStack(spacing: 14) {
                Image(.iconCloudArrowUpSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Color.paveAccent)
                VStack(spacing: 4) {
                    Text(title)
                        .textStyle(.action)
                        .foregroundStyle(Color.ink)
                    if let hint {
                        Text(hint)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.paveDropZone, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.paveFocusRing, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
            .contentShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    VaultUploadZone(title: "Tik om te uploaden", hint: "PDF, Word, tekst of foto, tot 20 MB", sources: [.files, .photos]) { _ in }
        .padding(24)
}
