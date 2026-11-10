import Foundation
import PAVECore

enum AuthServiceFactory {
    static func make(bundle: Bundle = .main) -> any AuthService {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else {
            return MockAuthService()
        }
        return SupabaseAuthService(projectURL: url, publishableKey: key)
    }
}
