import Foundation
import Observation
import PAVECore

enum AppPhase: Equatable {
    case loading
    case signedOut
    case pinSetup
    case locked
    case main
}

@Observable
final class AppState {
    private static let signedInKey = "isSignedIn"

    private(set) var phase: AppPhase = .loading
    /// A chat someone tapped in the iPhone's search; opened once the app is unlocked.
    var conversationToOpen: String?
    let authService: any AuthService
    private let pinVault: PinVault
    private let biometrics: any BiometricAuthenticating
    private let defaults: UserDefaults
    private var signedInAccountID: String?

    init(
        defaults: UserDefaults = .standard,
        authService: any AuthService = MockAuthService(),
        pinVault: PinVault = PinVault(storage: KeychainPinStorage()),
        biometrics: any BiometricAuthenticating = LocalBiometricAuthenticator()
    ) {
        self.defaults = defaults
        self.authService = authService
        self.pinVault = pinVault
        self.biometrics = biometrics
    }

    var isSignedIn: Bool {
        defaults.bool(forKey: Self.signedInKey)
    }

    var biometricKind: BiometricKind? {
        biometrics.kind
    }

    var canUnlockWithBiometrics: Bool {
        pinVault.isBiometricsEnabled && biometrics.kind != nil
    }

    func finishLoading() {
        guard phase == .loading else { return }
        guard isSignedIn else {
            phase = .signedOut
            return
        }
        phase = pinVault.hasPin ? .locked : .pinSetup
    }

    func signIn(accountID: String?) {
        guard phase == .signedOut else { return }
        defaults.set(true, forKey: Self.signedInKey)
        signedInAccountID = accountID
        if let accountID, pinVault.belongs(to: accountID) {
            phase = .main
        } else {
            pinVault.clear()
            phase = .pinSetup
        }
    }

    func completePinSetup(pin: String, useBiometrics: Bool) throws {
        guard phase == .pinSetup else { return }
        try pinVault.setPin(pin, biometricsEnabled: useBiometrics, accountID: signedInAccountID)
        phase = .main
    }

    func unlock(with pin: String) -> PinCheckResult {
        let result = pinVault.check(pin)
        switch result {
        case .correct:
            phase = .main
        case .lockedOut:
            signOut()
        case .incorrect:
            break
        }
        return result
    }

    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        guard phase == .locked, canUnlockWithBiometrics else { return false }
        guard await biometrics.authenticate(reason: "Ontgrendel PAVE") else { return false }
        guard phase == .locked else { return false }
        phase = .main
        return true
    }

    func authenticateForBiometricSetup() async -> Bool {
        await biometrics.authenticate(reason: "Zet snel ontgrendelen aan voor PAVE")
    }

    func signOut() {
        defaults.set(false, forKey: Self.signedInKey)
        AylaSpotlight.forget(in: defaults)
        conversationToOpen = nil
        phase = .signedOut
        Task { await authService.signOut() }
    }

    func forgetPin() {
        pinVault.clear()
        signOut()
    }
}
