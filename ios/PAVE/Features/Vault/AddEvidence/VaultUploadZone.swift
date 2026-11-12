import SwiftUI

/// The dashed area with the cloud: tap it and choose a file or a photo.
struct VaultUploadZone: View {
    let title: String
    var hint: String?
    let sources: [VaultFileSource]
    var height: CGFloat = 194
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
            VStack(spacing: 14) {
                Image(.iconCloudArrowUpSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Color.brandGreen)
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
            .background(Color.dropZone, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.focusRing, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .menuStyle(.button)
        .buttonStyle(.pave)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }
}

#Preview {
    VaultUploadZone(title: "Tik om te uploaden", hint: "PDF, Word, tekst of foto, tot 20 MB", sources: [.files, .photos]) { _ in }
        .padding(24)
}
