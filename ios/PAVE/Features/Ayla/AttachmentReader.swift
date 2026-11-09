import Foundation
import PAVECore
import PDFKit
import UniformTypeIdentifiers
import Vision

/// Reads the text of a file the user adds, on the device. Only that text goes to Ayla, never the file itself.
nonisolated enum AttachmentReader {
    enum Failure: Error {
        case unreadable
    }

    static let contentTypes: [UTType] = [.pdf, .image, .plainText, .text]

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
            text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
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
        guard let type = contentTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else {
            throw Failure.unreadable
        }
        let suggestedName = provider.suggestedName
        let copy: URL = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, error in
                guard let url else {
                    continuation.resume(throwing: error ?? Failure.unreadable)
                    return
                }
                // A pasted image has no name of its own, only a random one; then it gets a plain one.
                let plain = type.conforms(to: .image) ? "Geplakte afbeelding" : type.conforms(to: .pdf) ? "Geplakt document" : "Geplakte tekst"
                let name = "\(suggestedName ?? plain).\(url.pathExtension)"
                let target = FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
                    .appending(path: name)
                do {
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: target)
                    continuation.resume(returning: target)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        return try await read(copy)
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

    private static func recognizeText(in url: URL) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "nl-NL"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: url)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
