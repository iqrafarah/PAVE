import Foundation
import PAVECore

/// The employer's inbox of the fair demo talks to the real Supabase project, without signing in.
enum FairInboxServiceFactory {
    static func make(bundle: Bundle = .main) -> FairInboxService? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String, let url = URL(string: urlString), url.host() != nil,
              let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String, !key.isEmpty else { return nil }
        return FairInboxService(projectURL: url, publishableKey: key)
    }
}
