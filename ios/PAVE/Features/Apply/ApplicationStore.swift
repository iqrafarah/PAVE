import Foundation
import PAVECore

/// Keeps drafts on this device only, one file per vacancy, encrypted while the iPhone is locked. They do not go to the
/// server yet: where they live in the account is still to be decided with the web team.
struct ApplicationStore {
    private let folder: URL

    init(folder: URL = URL.applicationSupportDirectory.appending(path: "Applications", directoryHint: .isDirectory)) {
        self.folder = folder
    }

    func load(_ vacancyID: String) -> ApplicationDraft? {
        guard let data = try? Data(contentsOf: file(vacancyID)) else { return nil }
        return try? JSONDecoder().decode(ApplicationDraft.self, from: data)
    }

    func save(_ draft: ApplicationDraft) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: file(draft.id), options: [.atomic, .completeFileProtection])
    }

    private func file(_ vacancyID: String) -> URL {
        let safe = vacancyID.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" ? $0 : "_" }
        return folder.appending(path: String(safe) + ".json")
    }
}
