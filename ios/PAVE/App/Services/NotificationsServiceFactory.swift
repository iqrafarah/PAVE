import Foundation
import PAVECore

enum NotificationsServiceFactory {
    static func make(auth: any AuthService, bundle: Bundle = .main) -> SupabaseNotificationsService? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else { return nil }
        return SupabaseNotificationsService(projectURL: url, publishableKey: key) { await auth.accessToken() }
    }
}
