import PAVECore
import SwiftUI

/// How the evidence looks on its card, with the card shown live on top: a logo for the round avatar, and with or without
/// a cover. Without a cover the band takes the strongest colour of the logo; with one it shows your own photo. A chosen
/// image opens "Verplaatsen en schalen" first, and can be moved again later. Used for adding and for changing evidence.
struct VaultLookSection: View {
    let logo: VaultThumbnail.Source?
    let cover: VaultThumbnail.Source?
    @Binding var wantsCover: Bool
    let title: String
    let category: VaultCategory
    let onPick: (Result<VaultUpload, VaultUpload.Problem>) -> Void
    let onRemoveLogo: () -> Void
    let onRemoveCover: () -> Void

    private struct Framing: Identifiable {
        let id = UUID()
        let image: UIImage
        let role: VaultFileRole
    }

    @Environment(VaultModel.self) private var model: VaultModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var look: VaultLogoLook?
    @State private var logoSource: VaultFileSource?
    @State private var coverSource: VaultFileSource?
    @State private var framing: Framing?
    /// The image as chosen, so moving it again never loses what was cut off before.
    @State private var originals: [String: UIImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VaultCardPreview(look: look, cover: wantsCover ? cover : nil, title: title, category: category)
            logoRow
            coverSection
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy(duration: 0.35), value: wantsCover)
        .animation(.snappy(duration: 0.3), value: cover)
        .task(id: key(logo)) { await loadLook() }
        .vaultFilePicker(source: $logoSource, role: .logo) { picked($0, role: .logo) }
        .vaultFilePicker(source: $coverSource, role: .cover) { picked($0, role: .cover) }
        .fullScreenCover(item: $framing) { framing in
            VaultImageFramer(image: framing.image, shape: framing.role == .logo ? .circle : .band) { framed in
                use(framed, role: framing.role)
            }
        }
    }

    // MARK: Logo

    private var logoRow: some View {
        HStack(alignment: .center, spacing: 14) {
            Menu {
                if logo != nil {
                    Button { reframe(.logo) } label: { Label { Text(VaultMessages.reframe) } icon: { Image(.iconPencil) } }
                }
                sourceButtons { logoSource = $0 }
                if logo != nil {
                    Button(role: .destructive, action: onRemoveLogo) { Label { Text(VaultMessages.logoRemove) } icon: { Image(.iconTrash) } }
                }
            } label: {
                Group {
                    if logo != nil {
                        VaultLogoAvatar(look: look, name: title, size: 64)
                    } else {
                        Image(.iconPlus)
                            .renderingMode(.template)
                            .foregroundStyle(Color.paveAccent)
                            .paveIconFrame(64)
                            .background(Color.paveDropZone, in: .circle)
                            .overlay { Circle().strokeBorder(Color.paveFocusRing, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
                    }
                }
                .contentShape(.circle)
            }
            .menuStyle(.button)
            .buttonStyle(.pave)
            .accessibilityLabel(logo == nil ? VaultMessages.logoChoose : VaultMessages.logoTitle)
            VStack(alignment: .leading, spacing: 4) {
                Text(VaultMessages.logoTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(logo == nil ? VaultMessages.logoHint : VaultMessages.logoHintChosen)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Cover

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
                    if let cover {
                        coverRow(cover)
                    } else {
                        VaultUploadZone(title: VaultMessages.uploadTitle, hint: VaultMessages.coverHint, sources: [.photos, .files], isCompact: true) {
                            coverSource = $0
                        }
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

    private func coverRow(_ cover: VaultThumbnail.Source) -> some View {
        HStack(spacing: 12) {
            VaultThumbnail(source: cover)
                .frame(width: 88, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(VaultMessages.withCover)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                Text(VaultMessages.coverChosen)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button { reframe(.cover) } label: { Label { Text(VaultMessages.reframe) } icon: { Image(.iconPencil) } }
                sourceButtons { coverSource = $0 }
                Button(role: .destructive, action: onRemoveCover) { Label { Text(VaultMessages.coverRemove) } icon: { Image(.iconTrash) } }
            } label: {
                Image(.iconEllipsis)
                    .renderingMode(.template)
                    .foregroundStyle(Color.ink)
                    .paveIconFrame(44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(VaultMessages.coverActions)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
    }

    // MARK: Choosing and framing

    @ViewBuilder
    private func sourceButtons(_ choose: @escaping (VaultFileSource) -> Void) -> some View {
        Button { choose(.photos) } label: { Label { Text("Kies een foto") } icon: { Image(.iconPhotoSolid) } }
        Button { choose(.files) } label: { Label { Text("Kies een bestand") } icon: { Image(.iconDocumentSolid) } }
    }

    private func choose(_ value: Bool) {
        guard wantsCover != value else { return }
        PaveHaptics.selection()
        wantsCover = value
    }

    /// A chosen image goes to "Verplaatsen en schalen" first; only what you keep there is used.
    private func picked(_ result: Result<VaultUpload, VaultUpload.Problem>, role: VaultFileRole) {
        guard case .success(let upload) = result else {
            onPick(result)
            return
        }
        guard let image = UIImage(data: upload.data) else {
            onPick(.failure(.notAnImage))
            return
        }
        originals[role.rawValue] = image
        framing = Framing(image: image, role: role)
    }

    private func reframe(_ role: VaultFileRole) {
        if let original = originals[role.rawValue] {
            framing = Framing(image: original, role: role)
            return
        }
        let source = role == .logo ? logo : cover
        Task {
            let data: Data?
            switch source {
            case .upload(let upload): data = upload.data
            case .file(let file): data = await model?.data(of: file)
            case nil: data = nil
            }
            guard let data, let image = UIImage(data: data) else { return }
            originals[role.rawValue] = image
            framing = Framing(image: image, role: role)
        }
    }

    private func use(_ image: UIImage, role: VaultFileRole) {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        let name = role == .logo ? "Logo.jpeg" : "Omslag.jpeg"
        onPick(.success(VaultUpload(data: data, fileName: name, mimeType: "image/jpeg", role: role)))
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
