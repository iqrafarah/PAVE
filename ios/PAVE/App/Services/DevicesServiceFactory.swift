import Foundation
import PAVECore

enum DevicesServiceFactory {
    /// Only the real Supabase project has sessions; the demo login has none.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> (any DevicesService)? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else {
            return nil
        }
        return SupabaseDevicesService(projectURL: url, publishableKey: key) { await auth.accessToken() }
    }
}
