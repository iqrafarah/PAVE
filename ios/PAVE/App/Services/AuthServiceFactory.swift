import Foundation
import PAVECore
import UIKit

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
        return SupabaseAuthService(projectURL: url, publishableKey: key, userAgent: userAgent(bundle: bundle))
    }

    /// "PAVE-iOS/0.1 (iPhone; iOS 26.1)": how this app shows up in Ingelogde apparaten.
    static func userAgent(bundle: Bundle) -> String {
        SignedInDevice.appUserAgent(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion
        )
    }
}
