import Foundation
import PAVECore

enum ProfileServiceFactory {
    /// Only the real Supabase project has profiles; the demo login has none.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> (any ProfileService)? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else {
            return nil
        }
        return SupabaseProfileService(projectURL: url, publishableKey: key) { await auth.accessToken() }
    }
}
