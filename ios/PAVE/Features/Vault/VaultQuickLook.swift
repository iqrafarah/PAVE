import QuickLook
import SwiftUI

extension View {
    /// Shows a file full screen with QuickLook, from a temporary copy that is removed again when it closes.
    func vaultQuickLook(_ url: Binding<URL?>) -> some View {
        quickLookPreview(url)
            .onChange(of: url.wrappedValue) { old, new in
                guard new == nil, let old else { return }
                try? FileManager.default.removeItem(at: old.deletingLastPathComponent())
            }
    }
}

enum VaultPreviewFile {
    /// Writes the bytes under their own name, so QuickLook knows the type, in a folder of its own.
    static func url(for data: Data, named name: String) -> URL? {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "Kluis-voorbeeld", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: name.replacingOccurrences(of: "/", with: "-"))
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }
}
