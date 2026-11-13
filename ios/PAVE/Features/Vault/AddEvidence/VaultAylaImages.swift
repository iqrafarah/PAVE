import PAVECore
import PDFKit
import UIKit

/// Ayla's logo and cover in the shapes "Verplaatsen en schalen" makes, so they can be moved again like any other: a
/// 600 by 600 logo with the image whole on white, and a 1600 by 400 cover filled from the middle.
enum VaultAylaImages {
    private static let logoSide: CGFloat = 600
    private static let coverSize = CGSize(width: 1600, height: 400)

    /// The part of a document that Ayla pointed at, from the image itself or from its first page drawn sharp, so a logo
    /// cut from the corner of a certificate is not blurry. Without a box, the whole image.
    static func region(of upload: VaultUpload, box: VaultEvidenceProposal.Box?) -> Data? {
        let page: UIImage?
        if upload.isImage {
            page = UIImage(data: upload.data)
        } else if upload.mimeType == "application/pdf", let first = PDFDocument(data: upload.data)?.page(at: 0) {
            let size = first.bounds(for: .mediaBox).size
            let scale = 2400 / max(size.width, size.height, 1)
            page = first.thumbnail(of: CGSize(width: size.width * scale, height: size.height * scale), for: .mediaBox)
        } else {
            page = nil
        }
        guard let page, page.size.width > 0, page.size.height > 0 else { return nil }
        guard let box else { return page.jpegData(compressionQuality: 0.92) }
        let rect = CGRect(x: box.x * page.size.width, y: box.y * page.size.height, width: box.width * page.size.width, height: box.height * page.size.height)
            .intersection(CGRect(origin: .zero, size: page.size))
        guard rect.width >= 8, rect.height >= 8 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = page.scale
        format.opaque = true
        let cut = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            page.draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
        return cut.jpegData(compressionQuality: 0.92)
    }

    static func logo(from data: Data) -> VaultUpload? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        // Room around it for the round avatar; a small website icon is not blown up beyond three times its size.
        let box = min(logoSide * 0.72, max(pixels.width, pixels.height) * 3)
        let scale = min(box / pixels.width, box / pixels.height)
        let size = CGSize(width: pixels.width * scale, height: pixels.height * scale)
        let rendered = renderer(CGSize(width: logoSide, height: logoSide)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: logoSide, height: logoSide)))
            image.draw(in: CGRect(x: (logoSide - size.width) / 2, y: (logoSide - size.height) / 2, width: size.width, height: size.height))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: 0.88) else { return nil }
        return VaultUpload(data: jpeg, fileName: "Logo.jpeg", mimeType: "image/jpeg", role: .logo)
    }

    static func cover(from data: Data) -> VaultUpload? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = max(coverSize.width / image.size.width, coverSize.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rendered = renderer(coverSize).image { _ in
            image.draw(in: CGRect(x: (coverSize.width - size.width) / 2, y: (coverSize.height - size.height) / 2, width: size.width, height: size.height))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: 0.85) else { return nil }
        return VaultUpload(data: jpeg, fileName: "Omslag.jpeg", mimeType: "image/jpeg", role: .cover)
    }

    private static func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}
