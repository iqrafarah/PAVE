import Foundation
import PAVECore

enum VaultServiceFactory {
    /// The vault only runs against the real Supabase project. With the demo login there is no vault.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> (any VaultService)? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else {
            return nil
        }
        return SupabaseVaultService(projectURL: url, publishableKey: key) { await auth.accessToken() }
    }
}
