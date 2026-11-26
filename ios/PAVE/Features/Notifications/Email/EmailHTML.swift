import SafariServices
import SwiftUI
import WebKit

/// Mail as the sender laid it out. The chat bubble shows the text; a mail with a table, a list or pictures also gets
/// "Bekijk opgemaakt", which shows the HTML. Without scripts, and without pictures from the internet until you ask,
/// because those tell the sender when and where you opened the mail.
nonisolated enum EmailHTML {
    /// Only formatting the plain text loses is worth a button; a mail that is just paragraphs reads the same as text.
    static func hasFormatting(_ html: String) -> Bool {
        html.range(of: #"(?i)<(table|ul|ol|img|h[1-6]|blockquote|pre)\b"#, options: .regularExpression) != nil
    }

    /// Whether the mail has pictures from the internet, for "Afbeeldingen laden".
    static func hasRemoteImages(_ html: String) -> Bool {
        html.range(of: #"(?i)<img[^>]+src\s*=\s*["']?https?:"#, options: .regularExpression) != nil
    }

    /// The mail wrapped in a page that may show nothing from outside, or only pictures when `remoteImages` is on.
    static func page(_ html: String, remoteImages: Bool) -> String {
        let images = remoteImages ? "img-src data: https: http:;" : "img-src data:;"
        let policy = "default-src 'none'; style-src 'unsafe-inline'; font-src data:; \(images)"
        let cleaned = html
            .replacingOccurrences(of: #"(?is)<script\b.*?</script\s*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<meta[^>]+http-equiv[^>]*>"#, with: "", options: .regularExpression)
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(policy)">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html { color-scheme: light; -webkit-text-size-adjust: 100%; }
        body { margin: 16px; font: -apple-system-body; color: #1c1c1e; background: #ffffff; word-wrap: break-word; }
        img { max-width: 100%; height: auto; }
        table { max-width: 100%; }
        pre { white-space: pre-wrap; }
        </style></head><body>\(cleaned)</body></html>
        """
    }
}

/// "Opgemaakt": the mail in a sheet, with pictures off until you load them.
struct EmailFormattedSheet: View {
    let message: EmailMessage
    let html: String

    @Environment(\.dismiss) private var dismiss
    @State private var showsImages = false
    @State private var link: EmailLink?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if EmailHTML.hasRemoteImages(html), !showsImages {
                    HStack(spacing: 10) {
                        Text("Afbeeldingen staan uit, zodat de afzender niet ziet dat je de mail opent.")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                        Spacer(minLength: 8)
                        Button("Laden") { showsImages = true }
                            .textStyle(.link)
                            .foregroundStyle(Color.paveAccent)
                            .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .background(Color.panel)
                }
                EmailHTMLView(page: EmailHTML.page(html, remoteImages: showsImages)) { link = EmailLink(url: $0) }
                    .ignoresSafeArea(edges: .bottom)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(message.subject.isEmpty ? "E-mail" : message.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
            .sheet(item: $link) { link in
                EmailSafariView(url: link.url).ignoresSafeArea()
            }
        }
        .tint(.paveAccent)
    }
}

/// A link from the mail, for the sheet that opens it.
private struct EmailLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// A web view without JavaScript that opens links outside the mail.
struct EmailHTMLView: UIViewRepresentable {
    let page: String
    let onLink: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLink: onLink) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .white
        view.loadHTMLString(page, baseURL: nil)
        context.coordinator.page = page
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.page != page else { return }
        context.coordinator.page = page
        view.loadHTMLString(page, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLink: (URL) -> Void
        var page: String?

        init(onLink: @escaping (URL) -> Void) {
            self.onLink = onLink
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                return action.request.url?.scheme == "about" || action.navigationType == .other ? .allow : .cancel
            }
            if url.scheme == "http" || url.scheme == "https" {
                onLink(url)
            } else if url.scheme == "mailto" || url.scheme == "tel" {
                await UIApplication.shared.open(url)
            }
            return .cancel
        }
    }
}

struct EmailSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
