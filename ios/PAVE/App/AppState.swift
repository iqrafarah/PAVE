import Foundation
import Observation

enum AppPhase: Equatable {
    case loading
    case signedOut
    case main
}

@Observable
final class AppState {
    private static let signedInKey = "isSignedIn"

    private(set) var phase: AppPhase = .loading
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isSignedIn: Bool {
        defaults.bool(forKey: Self.signedInKey)
    }

    func finishLoading() {
        guard phase == .loading else { return }
        phase = isSignedIn ? .main : .signedOut
    }

    func signIn() {
        guard phase == .signedOut else { return }
        defaults.set(true, forKey: Self.signedInKey)
        phase = .main
    }

    func signOut() {
        defaults.set(false, forKey: Self.signedInKey)
        phase = .signedOut
    }
}
