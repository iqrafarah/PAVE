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

    private static func recognizeText(in url: URL) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "nl-NL"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: url)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
