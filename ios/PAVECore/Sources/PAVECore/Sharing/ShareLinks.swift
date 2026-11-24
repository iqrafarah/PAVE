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

    /// What a scanned QR code points to, when it is one of PAVE's; any host, so a test site works too.
    public static func scanned(_ text: String) -> Scanned? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        let (kind, value) = (parts[parts.count - 2].lowercased(), parts[parts.count - 1].lowercased())
        if kind == "gedeeld", value.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil { return .share(code: value) }
        if kind == "werkgever", value.range(of: "^[a-z0-9-]{2,40}$", options: .regularExpression) != nil { return .employer(slug: value) }
        return nil
    }
}
