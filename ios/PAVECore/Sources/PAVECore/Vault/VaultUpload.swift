import CryptoKit
import Foundation

/// What a file on an item is: the evidence itself, the image in the round avatar on its card (a logo), or the image in
/// the band above it (the cover).
public enum VaultFileRole: String, Equatable, Sendable {
    case document
    case cover
    case logo

    /// A cover and a logo have to be images.
    public var needsImage: Bool { self != .document }
}

/// A file you add to an item, checked the same way as the database and the storage bucket check it.
public struct VaultUpload: Equatable, Sendable {
    public enum Problem: Error, Equatable, Sendable {
        case empty
        case tooLarge
        case unsupportedType
        /// A cover or logo has to be a photo or image.
        case notAnImage
    }

    public let data: Data
    public let fileName: String
    public let mimeType: String
    public let role: VaultFileRole
    /// SHA-256 of the bytes, worked out once: it is stored with the file and tells files apart in the app.
    public let checksum: String

    public static let maximumBytes = 20_971_520
    public static let imageTypes: Set<String> = ["image/heic", "image/jpeg", "image/png"]
    public static let allowedTypes: Set<String> = imageTypes.union([
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "text/plain",
    ])

    public init(data: Data, fileName: String, mimeType: String, role: VaultFileRole = .document) {
        self.data = data
        let name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fileName = String((name.isEmpty ? "Bestand" : name).prefix(255))
        self.mimeType = mimeType.lowercased()
        self.role = role
        checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Compares by checksum instead of all bytes: views compare files on every change.
    public static func == (lhs: VaultUpload, rhs: VaultUpload) -> Bool {
        lhs.checksum == rhs.checksum && lhs.role == rhs.role && lhs.fileName == rhs.fileName && lhs.mimeType == rhs.mimeType
    }

    public var problem: Problem? {
        if data.isEmpty { return .empty }
        if data.count > Self.maximumBytes { return .tooLarge }
        if !Self.allowedTypes.contains(mimeType) { return .unsupportedType }
        if role.needsImage, !Self.imageTypes.contains(mimeType) { return .notAnImage }
        return nil
    }

    public var isImage: Bool { Self.imageTypes.contains(mimeType) }

    /// "PDF - 2,4 MB", as under the file name in the form.
    public var summary: String {
        "\(Self.kind(of: mimeType)) - \(Int64(data.count).formatted(.byteCount(style: .file).locale(Locale(identifier: "nl_NL"))))"
    }

    /// The name without its extension and with dashes as spaces: a first guess at a title.
    public var suggestedTitle: String {
        let base = (fileName as NSString).deletingPathExtension
        return base
            .replacing(/[-_]+/, with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    var fileExtension: String {
        Self.fileExtensions[mimeType] ?? "bin"
    }


    public static func mimeType(forExtension fileExtension: String) -> String? {
        let fileExtension = fileExtension.lowercased()
        if fileExtension == "jpg" { return "image/jpeg" }
        return fileExtensions.first { $0.value == fileExtension }?.key
    }

    /// "PDF", "Word", "JPG": how the type is named under the file.
    public static func kind(of mimeType: String) -> String {
        switch mimeType {
        case "application/pdf": "PDF"
        case "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "Word"
        case "text/plain": "Tekst"
        default: fileExtensions[mimeType]?.uppercased() ?? "Bestand"
        }
    }

    private static let fileExtensions = [
        "application/pdf": "pdf",
        "application/msword": "doc",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
        "text/plain": "txt",
        "image/heic": "heic",
        "image/jpeg": "jpeg",
        "image/png": "png",
    ]
}
