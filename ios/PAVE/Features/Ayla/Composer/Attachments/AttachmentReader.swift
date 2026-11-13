import Foundation
import PAVECore
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

/// Reads the text of a file the user adds, on the device. Only that text goes to Ayla, never the file itself.
nonisolated enum AttachmentReader {
    enum Failure: Error {
        case unreadable
        /// There is something on the clipboard, but iOS did not hand it over (pasting was not allowed).
        case refused
    }

    static let contentTypes: [UTType] = [.pdf, .image, .plainText, .text]

    /// A chosen file with its text, and the file itself when the vault accepts its kind and size.
    @concurrent
    static func file(_ url: URL) async throws -> AylaChatFile {
        let attachment = try await read(url)
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        guard let mimeType = type.preferredMIMEType, let data = try? Data(contentsOf: url) else { return AylaChatFile(attachment: attachment, upload: nil) }
        let upload = VaultUpload(data: data, fileName: url.lastPathComponent, mimeType: mimeType)
        return AylaChatFile(attachment: attachment, upload: upload.problem == nil ? upload : nil)
    }

    /// A dragged or pasted file, with the file itself when the vault accepts it.
    static func file(_ provider: NSItemProvider) async throws -> AylaChatFile {
        try await withCopy(of: provider) { try await file($0) }
    }

    /// The scanned pages as one PDF, with its text, so the scan itself can go into the vault.
    @concurrent
    static func file(pages: [CGImage], name: String) async throws -> AylaChatFile {
        let attachment = try await read(pages: pages, name: name)
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { context in
            for page in pages {
                let image = UIImage(cgImage: page)
                let bounds = context.pdfContextBounds
                let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                context.beginPage()
                image.draw(in: CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
            }
        }
        let upload = VaultUpload(data: pdf, fileName: name, mimeType: "application/pdf")
        return AylaChatFile(attachment: attachment, upload: upload.problem == nil ? upload : nil)
    }

    @concurrent
    static func read(_ url: URL) async throws -> AylaAttachment {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        let text: String
        if type.conforms(to: .pdf) {
            text = PDFDocument(url: url)?.string ?? ""
        } else if type.conforms(to: .image) {
            text = try await recognizeText(in: url)
        } else if type.conforms(to: .text) {
            let data = try Data(contentsOf: url)
            let raw = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            // A web page is mostly markup: Ayla gets its words.
            text = type.conforms(to: .html) ? plainText(fromHTML: raw) : raw
        } else {
            throw Failure.unreadable
        }
        guard let attachment = AylaAttachment(name: url.lastPathComponent, text: text) else { throw Failure.unreadable }
        return attachment
    }

    /// A file that was dragged in or pasted: the first kind PAVE can read, copied before it is read, because iOS
    /// only lends the original for a moment. Runs where it is called from (the provider may not travel); reading
    /// the copy happens in the background.
    static func read(_ provider: NSItemProvider) async throws -> AylaAttachment {
        try await withCopy(of: provider) { try await read($0) }
    }

    /// The provider's file copied to a file of our own for as long as `use` runs.
    private static func withCopy<T>(of provider: NSItemProvider, _ use: (URL) async throws -> T) async throws -> T {
        guard let type = contentTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else {
            throw Failure.unreadable
        }
        let suggestedName = provider.suggestedName
        // The concrete kind (png, jpeg, pdf): iOS cannot load a clipboard image as just "an image".
        // The clipboard also offers an internal UIKit kind first, which cannot be loaded as a file.
        let concrete = provider.registeredContentTypes.first { $0.conforms(to: type) && $0.preferredFilenameExtension != nil } ?? type
        // A clipboard image often exists only as data, not as a file, so the data is written to a file of our own,
        // with the extension of its kind, so it can be read.
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(for: concrete) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? Failure.unreadable)
                }
            }
        }
        let plain = type.conforms(to: .image) ? "Geplakte afbeelding" : type.conforms(to: .pdf) ? "Geplakt document" : "Geplakte tekst"
        let fileExtension = concrete.preferredFilenameExtension ?? type.preferredFilenameExtension ?? "png"
        let copy = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "\(suggestedName ?? plain).\(fileExtension)")
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: copy)
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        return try await use(copy)
    }

    /// A photo or pdf from the clipboard, written to a file of our own so it can be read like any other.
    /// Reading the clipboard is what iOS may ask permission for ("PAVE wil plakken").
    @MainActor
    static func clipboardFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let pdf = UIPasteboard.general.data(forPasteboardType: UTType.pdf.identifier) {
            let url = folder.appending(path: "Geplakt document.pdf")
            try pdf.write(to: url)
            return url
        }
        if let image = UIPasteboard.general.image, let png = image.pngData() {
            let url = folder.appending(path: "Geplakte afbeelding.png")
            try png.write(to: url)
            return url
        }
        try? FileManager.default.removeItem(at: folder)
        let hasFile = UIPasteboard.general.hasImages || UIPasteboard.general.contains(pasteboardTypes: [UTType.pdf.identifier])
        throw hasFile ? Failure.refused : Failure.unreadable
    }

    /// The pages of a scanned document, read on the device into one attachment.
    @concurrent
    static func read(pages: [CGImage], name: String) async throws -> AylaAttachment {
        var texts: [String] = []
        for page in pages {
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = [Locale.Language(identifier: "nl-NL"), Locale.Language(identifier: "en-US")]
            let observations = try await request.perform(on: page)
            texts.append(observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n"))
        }
        guard let attachment = AylaAttachment(name: name, text: texts.joined(separator: "\n\n")) else { throw Failure.unreadable }
        return attachment
    }

    /// The visible text of HTML: scripts and styles out, tags out, entities and whitespace tidied.
    static func plainText(fromHTML html: String) -> String {
        var text = html.replacing(/<(script|style)[^>]*>[\s\S]*?<\/\1>/.ignoresCase(), with: " ")
        text = text.replacing(/<br\s*\/?>|<\/(p|div|li|h[1-6]|tr|section|article)>/.ignoresCase(), with: "\n")
        text = text.replacing(/<[^>]+>/, with: " ")
        for (entity, plain) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&euro;", "€")] {
            text = text.replacingOccurrences(of: entity, with: plain)
        }
        return text.replacing(/[ \t]+/, with: " ").replacing(/\s*\n\s*/, with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func recognizeText(in url: URL) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "nl-NL"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: url)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
