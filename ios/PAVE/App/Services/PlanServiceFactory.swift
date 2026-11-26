import Foundation
import PAVECore

enum PlanServiceFactory {
    /// Plans live in the real Supabase project; the demo login keeps them in memory only, for as long as the app runs.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> any PlanService {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else {
            return LocalPlanService(fileURL: nil)
        }
        return SupabasePlanService(projectURL: url, publishableKey: key) { await auth.accessToken() }
    }
}
