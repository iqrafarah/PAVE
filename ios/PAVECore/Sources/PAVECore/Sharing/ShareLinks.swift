import Foundation

/// The addresses of sharing: a share opens at `/gedeeld/{code}` on the website, an employer's card at
/// `/werkgever/{slug}`. A QR code holds the same address, so a phone camera opens it too.
public enum ShareLinks {
    public enum Scanned: Equatable, Sendable {
        case share(code: String)
        case employer(slug: String)
    }

    public static func share(_ code: String, base: URL) -> URL {
        base.appending(path: "gedeeld").appending(path: code)
    }

    public static func employer(_ slug: String, base: URL) -> URL {
        base.appending(path: "werkgever").appending(path: slug)
    }

    /// An employer's card in the app itself: the iPhone's camera offers "Open in PAVE" for this code.
    public static func employerInApp(_ slug: String) -> URL {
        URL(string: "pave://werkgever/\(slug)")!
    }

    /// What a scanned QR code points to, when it is one of PAVE's: a web address on any host, so a test site works
    /// too, or the app's own `pave://werkgever/{slug}`.
    public static func scanned(_ text: String) -> Scanned? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), let scheme = url.scheme?.lowercased() else { return nil }
        var parts = url.pathComponents.filter { $0 != "/" }
        if scheme == "pave", let host = url.host() { parts.insert(host, at: 0) }
        guard scheme == "https" || scheme == "http" || scheme == "pave", parts.count >= 2 else { return nil }
        let (kind, value) = (parts[parts.count - 2].lowercased(), parts[parts.count - 1].lowercased())
        if kind == "gedeeld", value.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil { return .share(code: value) }
        if kind == "werkgever", value.range(of: "^[a-z0-9-]{2,40}$", options: .regularExpression) != nil { return .employer(slug: value) }
        return nil
    }
}
