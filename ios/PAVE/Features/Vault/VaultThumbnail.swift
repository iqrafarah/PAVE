import PAVECore
import PDFKit
import SwiftUI

/// A small picture of a file: the photo itself, the first page of a PDF, or an icon for anything else. Files in the
/// vault are fetched with your session; a file you are still adding is read from the phone.
struct VaultThumbnail: View {
    enum Source: Equatable {
        case upload(VaultUpload)
        case file(VaultItem.File)

        fileprivate var key: String {
            switch self {
            case .upload(let upload): "upload-\(upload.checksum)"
            case .file(let file): "file-\(file.id)"
            }
        }

        fileprivate var mimeType: String {
            switch self {
            case .upload(let upload): upload.mimeType
            case .file(let file): file.mimeType
            }
        }
    }

    let source: Source
    var cornerRadius: CGFloat = 7
    @Environment(VaultModel.self) private var model: VaultModel?
    @State private var image: UIImage?
    @State private var size: CGSize = .zero

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        // The frame decides the size; the picture fills it and is cut off at its edges, never the other way round.
        Color.hairline
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(source.mimeType.hasPrefix("image/") ? .iconPhotoSolid : .iconDocumentSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(Color.paveAccent)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .animation(.easeOut(duration: 0.25), value: image != nil)
        .task(id: source.key) { await load() }
        .accessibilityHidden(true)
    }

    private func load() async {
        let key = source.key as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }
        let data: Data?
        switch source {
        case .upload(let upload): data = upload.data
        case .file(let file): data = await model?.data(of: file)
        }
        guard let data else { return }
        let side = max(size.width, size.height, 44) * 3
        guard let rendered = await Self.render(data, mimeType: source.mimeType, side: side) else { return }
        Self.cache.setObject(rendered, forKey: key)
        image = rendered
    }

    nonisolated private static func render(_ data: Data, mimeType: String, side: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let target = CGSize(width: side, height: side)
            if mimeType.hasPrefix("image/") {
                return UIImage(data: data)?.preparingThumbnail(of: target)
            }
            if mimeType == "application/pdf", let page = PDFDocument(data: data)?.page(at: 0) {
                return page.thumbnail(of: target, for: .mediaBox)
            }
            return nil
        }.value
    }
}

#Preview {
    VaultThumbnail(source: .upload(VaultUpload(data: Data(), fileName: "a.pdf", mimeType: "application/pdf")))
        .frame(width: 41, height: 41)
        .padding()
}
