import Foundation
import PAVECore
import PDFKit
import UIKit

/// Reads the documents of an evidence item into what Ayla can look at: the text of a PDF or text file, and a small photo
/// of an image or of a PDF without text (a scan). A Word file cannot be read here and is left out.
enum VaultSkillsMaterialReader {
    nonisolated static let photoSide: CGFloat = 1024
    /// A PDF with less text than this is probably a scan: Ayla gets a photo of its first page instead.
    nonisolated static let minimumPDFText = 40

    static func read(_ uploads: [VaultUpload]) async -> VaultSkillsMaterial {
        await Task.detached(priority: .userInitiated) {
            var material = VaultSkillsMaterial()
            for upload in uploads where upload.role == .document {
                if let text = text(of: upload) {
                    material.texts.append(.init(name: upload.fileName, text: text))
                } else if material.images.count < VaultSkillsMaterial.maximumImages, let jpeg = photo(of: upload) {
                    material.images.append(.init(name: upload.fileName, jpeg: jpeg))
                }
            }
            return material
        }.value
    }

    nonisolated static func text(of upload: VaultUpload) -> String? {
        let raw: String? = switch upload.mimeType {
        case "application/pdf": PDFDocument(data: upload.data)?.string
        case "text/plain": String(data: upload.data, encoding: .utf8) ?? String(data: upload.data, encoding: .isoLatin1)
        default: nil
        }
        guard let clean = raw?.trimmingCharacters(in: .whitespacesAndNewlines), clean.count >= (upload.mimeType == "application/pdf" ? minimumPDFText : 1) else {
            return nil
        }
        return String(clean.prefix(VaultSkillsMaterial.maximumTextLength))
    }

    nonisolated static func photo(of upload: VaultUpload) -> Data? {
        let size = CGSize(width: photoSide, height: photoSide)
        let image: UIImage?
        if upload.isImage, let original = UIImage(data: upload.data) {
            image = original.preparingThumbnail(of: fitting(original.size, in: size))
        } else if upload.mimeType == "application/pdf", let page = PDFDocument(data: upload.data)?.page(at: 0) {
            image = page.thumbnail(of: fitting(page.bounds(for: .mediaBox).size, in: size), for: .mediaBox)
        } else {
            image = nil
        }
        return image?.jpegData(compressionQuality: 0.7)
    }

    /// The largest size with the same shape that fits in `box`, never larger than the original.
    nonisolated static func fitting(_ original: CGSize, in box: CGSize) -> CGSize {
        guard original.width > 0, original.height > 0 else { return box }
        let scale = min(1, box.width / original.width, box.height / original.height)
        return CGSize(width: (original.width * scale).rounded(), height: (original.height * scale).rounded())
    }
}
