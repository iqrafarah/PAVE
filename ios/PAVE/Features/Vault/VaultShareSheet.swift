import PAVECore
import SwiftUI
import UIKit

/// "Downloaden": the files go to the iPhone's share sheet, where "Bewaar in Bestanden" saves them, as a download does
/// on the web. Nothing is sent anywhere until you choose where.
struct VaultShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// The files that are ready to be downloaded, for `.sheet(item:)`.
struct VaultDownload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

extension VaultModel {
    /// Fetches the files and writes them under their own names; nil when one of them cannot be fetched now.
    func download(_ files: [VaultItem.File]) async -> VaultDownload? {
        var urls = [URL]()
        for file in files {
            guard let data = await data(of: file), let url = VaultPreviewFile.url(for: data, named: file.name) else { return nil }
            urls.append(url)
        }
        return urls.isEmpty ? nil : VaultDownload(urls: urls)
    }
}
