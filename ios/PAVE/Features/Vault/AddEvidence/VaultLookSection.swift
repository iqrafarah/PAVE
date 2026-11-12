import PAVECore
import SwiftUI

/// How the evidence looks on its card, with the card shown live on top: a logo for the round avatar, and with or without
/// a cover. Without a cover the band takes the strongest colour of the logo; with one it shows your own photo. Used for
/// adding and for changing evidence.
struct VaultLookSection: View {
    let logo: VaultThumbnail.Source?
    let cover: VaultThumbnail.Source?
    @Binding var wantsCover: Bool
    let title: String
    let category: VaultCategory
    let onChooseLogo: (VaultFileSource) -> Void
    let onRemoveLogo: () -> Void
    let onChooseCover: (VaultFileSource) -> Void
    let onRemoveCover: () -> Void

    @Environment(VaultModel.self) private var model: VaultModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var look: VaultLogoLook?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VaultCardPreview(look: look, cover: wantsCover ? cover : nil, title: title, category: category)
            logoRow
            coverSection
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy(duration: 0.35), value: wantsCover)
        .animation(.snappy(duration: 0.3), value: cover)
        .task(id: key(logo)) { await loadLook() }
    }

    private var logoRow: some View {
        HStack(alignment: .center, spacing: 14) {
            Menu {
                sourceButtons(onChooseLogo)
            } label: {
                Group {
                    if logo != nil {
                        VaultLogoAvatar(look: look, name: title, size: 64)
                    } else {
                        Image(.iconPlus)
                            .renderingMode(.template)
                            .foregroundStyle(Color.brandGreen)
                            .frame(width: 64, height: 64)
                            .background(Color.dropZone, in: .circle)
                            .overlay { Circle().strokeBorder(Color.focusRing, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
                    }
                }
                .contentShape(.circle)
            }
            .menuStyle(.button)
            .buttonStyle(.pave)
            .accessibilityLabel(logo == nil ? VaultMessages.logoChoose : VaultMessages.logoReplace)
            VStack(alignment: .leading, spacing: 4) {
                Text(VaultMessages.logoTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.logoHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if logo != nil {
                    Button(VaultMessages.logoRemove, role: .destructive, action: onRemoveLogo)
                        .textStyle(.link)
                        .foregroundStyle(Color.critical)
                        .frame(minHeight: 32)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(VaultMessages.coverTitle)
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                VaultCoverOption(title: VaultMessages.noCover, image: .vaultCoverNone, isSelected: !wantsCover) { choose(false) }
                VaultCoverOption(title: VaultMessages.withCover, image: .vaultCoverPhoto, isSelected: wantsCover) { choose(true) }
            }
            if wantsCover {
                Group {
                    switch cover {
                    case .upload(let upload):
                        VaultFileRow(upload: upload, onRemove: onRemoveCover)
                    case .file(let file):
                        VaultRemoteFileRow(file: file, onRemove: onRemoveCover)
                    case nil:
                        VaultUploadZone(title: VaultMessages.uploadTitle, hint: VaultMessages.coverHint, sources: [.photos, .files], isCompact: true, onChoose: onChooseCover)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(logo == nil ? VaultMessages.noCoverWithoutLogo : VaultMessages.noCoverWithLogo)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func sourceButtons(_ onChoose: @escaping (VaultFileSource) -> Void) -> some View {
        Button { onChoose(.photos) } label: { Label { Text("Kies een foto") } icon: { Image(.iconPhotoSolid) } }
        Button { onChoose(.files) } label: { Label { Text("Kies een bestand") } icon: { Image(.iconDocumentSolid) } }
    }

    private func choose(_ value: Bool) {
        guard wantsCover != value else { return }
        PaveHaptics.selection()
        wantsCover = value
    }

    private func key(_ source: VaultThumbnail.Source?) -> String {
        switch source {
        case .upload(let upload): upload.checksum
        case .file(let file): file.id
        case nil: ""
        }
    }

    private func loadLook() async {
        let loaded: VaultLogoLook?
        switch logo {
        case .upload(let upload): loaded = await VaultLogoLook.make(from: upload.data)
        case .file(let file): loaded = await model?.look(of: file)
        case nil: loaded = nil
        }
        withAnimation(.easeOut(duration: 0.25)) { look = loaded }
    }
}
