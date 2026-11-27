import QuickLook
import SwiftUI

/// A file of the vault, opened (web VaultFilePreview): the name on top with "Downloaden" and a cross to close, and the
/// file below, shown by QuickLook (photos, PDFs, Word and text). Swipe down closes it too.
struct VaultFileViewer: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    /// A page in the stack of the sheet it is opened from (back button), instead of a cover of its own over it.
    var isPushed = false

    @State private var download: VaultDownload?

    var body: some View {
        if isPushed {
            page
                .sheet(item: $download) { VaultShareSheet(urls: $0.urls).presentationDetents([.medium, .large]) }
        } else {
            NavigationStack { page }
                .tint(.paveAccent)
                .sheet(item: $download) { VaultShareSheet(urls: $0.urls).presentationDetents([.medium, .large]) }
                .gesture(DragGesture(minimumDistance: 40).onEnded { value in
                    if value.translation.height > 120, abs(value.translation.width) < 80 { dismiss() }
                })
        }
    }

    private var page: some View {
            QuickLookContent(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !isPushed {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(.iconXMark)
                                .paveToolbarHitArea()
                        }
                        .accessibilityLabel("Bestand sluiten")
                    }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(VaultMessages.download) {
                            PaveHaptics.selection()
                            download = VaultDownload(urls: [url])
                        }
                        .accessibilityLabel(VaultMessages.downloadFile(url.lastPathComponent))
                    }
                }
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }
}

/// QuickLook inside the page, without its own bar: the page above has the buttons.
private struct QuickLookContent: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
