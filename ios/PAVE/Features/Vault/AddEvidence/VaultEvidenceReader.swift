import Foundation
import PAVECore

/// What "Laat Ayla invullen" sends, and the pictures it took out of Word files.
struct VaultEvidenceReading {
    /// One entry per chosen file, in the same order, followed by the pictures from Word files.
    var documents: [VaultEvidenceDocument]
    /// Those pictures as they were in the file, for cutting a logo or a cover from them; the first is document
    /// number `uploads.count`.
    var pictures: [VaultUpload]
}

/// Reads the documents for "Laat Ayla invullen", one entry per document in the same order, so Ayla's numbers point at
/// the right file: the text of a PDF, Word or text file, and a photo of an image or of the first page of a PDF, so Ayla
/// also sees the logo on a certificate or a photo in a report and can point at it. The pictures in a Word file (its
/// letterhead logo, its photos) follow as extra images; they are never documents of the item themselves.
enum VaultEvidenceReader {
    /// Large enough for Ayla to point at a logo in the corner of a page.
    nonisolated static let imageSide: CGFloat = 1400
    nonisolated static let maximumPictures = 4
    nonisolated static let wordType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    static func read(_ uploads: [VaultUpload]) async -> VaultEvidenceReading {
        await Task.detached(priority: .userInitiated) {
            var reading = VaultEvidenceReading(documents: [], pictures: [])
            for upload in uploads {
                let hasPage = upload.isImage || upload.mimeType == "application/pdf"
                reading.documents.append(VaultEvidenceDocument(
                    name: upload.fileName,
                    text: VaultSkillsMaterialReader.text(of: upload),
                    image: hasPage ? VaultSkillsMaterialReader.photo(of: upload, side: imageSide) : nil
                ))
            }
            for upload in uploads where upload.mimeType == wordType {
                for data in VaultWordText.images(of: upload.data) where reading.pictures.count < maximumPictures {
                    let picture = VaultUpload(data: data, fileName: "Afbeelding \(reading.pictures.count + 1) uit \(upload.fileName)", mimeType: "image/jpeg")
                    guard let photo = VaultSkillsMaterialReader.photo(of: picture, side: imageSide) else { continue }
                    reading.pictures.append(picture)
                    reading.documents.append(VaultEvidenceDocument(name: picture.fileName, image: photo))
                }
            }
            return reading
        }.value
    }
}
