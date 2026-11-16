import Foundation
import Observation
import PAVECore

enum AppPhase: Equatable {
    case loading
    case signedOut
    case pinSetup
    case locked
    case main
    /// The session ended elsewhere, for example because the password was changed on another device.
    case sessionEnded
}

@Observable
final class AppState {
    private static let signedInKey = "isSignedIn"
    /// How long the app may be away before it asks for the PIN or Face ID again, in seconds (0: at once).
    static let lockAfterKey = "lockAfterSeconds"
    static let defaultLockAfter = 300

    private(set) var phase: AppPhase = .loading
    /// A chat someone tapped in the iPhone's search; opened once the app is unlocked.
    var conversationToOpen: String?
    /// Something asked from outside the app (Siri, a widget, Control Center); done once the app is unlocked.
    var link: PaveLink?
    /// The app came back after being away too long: the PIN screen lies over it, so the open chat and what you were
    /// typing stay where they are.
    private(set) var isRelocked = false
    private var backgroundedAt: Date?
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
        PaveLinkInbox.receive = { [weak self] link in self?.link = link }
    }

    /// Signed in on this iPhone, also while the PIN screen is up; the Watch may then ask for the session.
    static func isSignedIn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: signedInKey)
    }

    /// Whether the app is unlocked and showing your things.
    var isOpen: Bool { phase == .main && !isRelocked }

    var lockAfter: TimeInterval {
        TimeInterval(defaults.object(forKey: Self.lockAfterKey) as? Int ?? Self.defaultLockAfter)
    }

    func didEnterBackground(at date: Date = .now) {
        guard phase == .main, !isRelocked else { return }
        backgroundedAt = date
    }

    func didBecomeActive(at date: Date = .now) {
        defer { backgroundedAt = nil }
        guard phase == .main, let backgroundedAt, pinVault.hasPin else { return }
        if date.timeIntervalSince(backgroundedAt) >= lockAfter { isRelocked = true }
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
            if isRelocked { isRelocked = false } else { phase = .main }
        case .lockedOut:
            signOut()
        case .incorrect:
            break
        }
        return result
    }

    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        guard phase == .locked || isRelocked, canUnlockWithBiometrics else { return false }
        guard await biometrics.authenticate(reason: "Ontgrendel PAVE") else { return false }
        if isRelocked {
            isRelocked = false
        } else {
            guard phase == .locked else { return false }
            phase = .main
        }
        return true
    }

    func authenticateForBiometricSetup() async -> Bool {
        await biometrics.authenticate(reason: "Zet snel ontgrendelen aan voor PAVE")
    }

    func signOut() {
        leave(to: .signedOut)
    }

    /// Asks the server whether the session still exists. When it ended elsewhere, a screen asks you to sign in again
    /// instead of showing things that can no longer load. Without an answer nothing changes.
    func checkSession() async {
        guard hasSession, await authService.sessionState() == .ended, hasSession else { return }
        leave(to: .sessionEnded)
    }

    func signInAgain() {
        guard phase == .sessionEnded else { return }
        phase = .signedOut
    }

    private var hasSession: Bool {
        isSignedIn && [.pinSetup, .locked, .main].contains(phase)
    }

    private func leave(to phase: AppPhase) {
        defaults.set(false, forKey: Self.signedInKey)
        AylaSpotlight.forget(in: defaults)
        AylaDrafts.forget(in: defaults)
        conversationToOpen = nil
        link = nil
        isRelocked = false
        self.phase = phase
        Task { await authService.signOut() }
    }

    func forgetPin() {
        pinVault.clear()
        signOut()
    }
}
