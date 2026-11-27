import QuickLook
import SwiftUI

extension View {
    /// Shows a file full screen (web VaultFilePreview): its name on top with "Downloaden" and a cross to close, the file
    /// itself below. The temporary copy is removed again when it closes.
    func vaultQuickLook(_ url: Binding<URL?>) -> some View {
        fullScreenCover(item: Binding(
            get: { url.wrappedValue.map(VaultOpenFile.init) },
            set: { url.wrappedValue = $0?.url }
        )) { file in
            VaultFileViewer(url: file.url)
        }
        .onChange(of: url.wrappedValue) { old, new in
            guard new == nil, let old else { return }
            try? FileManager.default.removeItem(at: old.deletingLastPathComponent())
        }
    }
}

extension View {
    /// The same file, as a page in the stack this view is in (back button), for a sheet that already has one: no
    /// cover of its own on top of it.
    func vaultFilePage(_ url: Binding<URL?>) -> some View {
        navigationDestination(item: Binding(
            get: { url.wrappedValue.map(VaultOpenFile.init) },
            set: { url.wrappedValue = $0?.url }
        )) { file in
            VaultFileViewer(url: file.url, isPushed: true)
        }
        .onChange(of: url.wrappedValue) { old, new in
            guard new == nil, let old else { return }
            try? FileManager.default.removeItem(at: old.deletingLastPathComponent())
        }
    }
}

private struct VaultOpenFile: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
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
