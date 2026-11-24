import Foundation
import PAVECore

enum ShareServiceFactory {
    /// Sharing only runs against the real Supabase project; the demo login has nothing to share from.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> (any ShareService)? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else {
            return nil
        }
        return SupabaseShareService(projectURL: url, publishableKey: key) { await auth.accessToken() }
    }

    /// Where the website with the recipient's page runs (`PAVE_WEB_URL` in Local.xcconfig); nil when not set.
    static func webURL(bundle: Bundle = .main) -> URL? {
        guard let text = bundle.object(forInfoDictionaryKey: "PaveWebURL") as? String, let url = URL(string: text), url.host() != nil else { return nil }
        return url
    }
}
