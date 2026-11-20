import Foundation
import PAVECore

/// The files sent in a chat that are still meant for the vault, kept per chat on this device, so evidence you were
/// still building is there again after you leave the chat or reopen the app. Gone when the item goes into the vault,
/// when the chat is deleted, and when you sign out.
final class AylaPendingFiles {
    private struct Entry: Codable {
        let file: String
        let fileName: String
        let mimeType: String
    }

    /// Nil keeps nothing (previews and tests).
    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    static var standard: AylaPendingFiles {
        AylaPendingFiles(directory: root)
    }

    private static var root: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "AylaPendingFiles", directoryHint: .isDirectory)
    }

    func save(_ uploads: [VaultUpload], for conversationID: String) {
        guard let folder = folder(for: conversationID) else { return }
        try? FileManager.default.removeItem(at: folder)
        guard !uploads.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var entries: [Entry] = []
            for (index, upload) in uploads.enumerated() {
                let name = "\(index).bin"
                try upload.data.write(to: folder.appending(path: name), options: .completeFileProtection)
                entries.append(Entry(file: name, fileName: upload.fileName, mimeType: upload.mimeType))
            }
            try JSONEncoder().encode(entries).write(to: folder.appending(path: "index.json"), options: .completeFileProtection)
        } catch {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func load(for conversationID: String) -> [VaultUpload] {
        guard let folder = folder(for: conversationID),
              let index = try? Data(contentsOf: folder.appending(path: "index.json")),
              let entries = try? JSONDecoder().decode([Entry].self, from: index) else { return [] }
        return entries.compactMap { entry in
            guard let data = try? Data(contentsOf: folder.appending(path: entry.file)) else { return nil }
            let upload = VaultUpload(data: data, fileName: entry.fileName, mimeType: entry.mimeType)
            return upload.problem == nil ? upload : nil
        }
    }

    func remove(_ conversationIDs: some Sequence<String>) {
        for id in conversationIDs {
            if let folder = folder(for: id) { try? FileManager.default.removeItem(at: folder) }
        }
    }

    static func forget() {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    /// The id is the server's, but it only ever names a folder here after leaving out anything that is not a plain character.
    private func folder(for conversationID: String) -> URL? {
        let safe = conversationID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard let directory, !safe.isEmpty else { return nil }
        return directory.appending(path: safe, directoryHint: .isDirectory)
    }
}
