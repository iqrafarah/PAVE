import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct AppStateTests {
    private struct StubBiometrics: BiometricAuthenticating {
        var kind: BiometricKind? = .faceID
        var succeeds = true

        func authenticate(reason: String) async -> Bool { succeeds }
    }

    private let defaults = UserDefaults(suiteName: "AppStateTests-\(UUID().uuidString)")!
    private let storage = InMemoryPinStorage()
    private let pin = "482916"
    private let ravi = "ravi-account"
    private let gianna = "gianna-account"

    /// Answers the session check with a fixed state; nothing else is used by these tests.
    private actor SessionStub: AuthService {
        let state: SessionState

        init(_ state: SessionState) {
            self.state = state
        }

        func sessionState() async -> SessionState { state }
        func signIn(email: String, password: String) async throws -> SignInOutcome { throw AuthError.unavailable }
        func verify(code: String) async throws {}
        func startVerificationSetup() async throws -> VerificationEnrollment { throw AuthError.unavailable }
        func confirmVerificationSetup(code: String) async throws {}
        func requestPasswordReset(email: String) async throws {}
        func verifyPasswordResetCode(email: String, code: String) async throws -> PasswordResetOutcome { throw AuthError.unavailable }
        func updatePassword(_ newPassword: String) async throws {}
        func signOut() async {}
        func accountID() async -> String? { nil }
        func accessToken() async -> String? { nil }
    }

    private func makeState(biometrics: StubBiometrics = StubBiometrics(), session: SessionState = .active) -> AppState {
        AppState(defaults: defaults, authService: SessionStub(session), pinVault: PinVault(storage: storage), biometrics: biometrics)
    }

    private func signedInState(session: SessionState = .active) throws -> AppState {
        let state = makeState(session: session)
        state.finishLoading()
        state.signIn(accountID: ravi)
        try state.completePinSetup(pin: pin, useBiometrics: false)
        return state
    }

    @Test func comingBackAfterTheLockTimeAsksForThePinOverTheApp() throws {
        let state = try signedInState()
        let away = Date(timeIntervalSince1970: 1_000)
        state.didEnterBackground(at: away)
        state.didBecomeActive(at: away.addingTimeInterval(TimeInterval(AppState.defaultLockAfter)))
        #expect(state.isRelocked)
        #expect(state.phase == .main)
        #expect(!state.isOpen)

        #expect(state.unlock(with: pin) == .correct)
        #expect(!state.isRelocked)
        #expect(state.isOpen)
    }

    @Test func aShortTimeAwayDoesNotLock() throws {
        let state = try signedInState()
        let away = Date(timeIntervalSince1970: 1_000)
        state.didEnterBackground(at: away)
        state.didBecomeActive(at: away.addingTimeInterval(30))
        #expect(!state.isRelocked)
    }

    @Test func lockingAtOnceIsASetting() throws {
        let state = try signedInState()
        defaults.set(0, forKey: AppState.lockAfterKey)
        let away = Date(timeIntervalSince1970: 1_000)
        state.didEnterBackground(at: away)
        state.didBecomeActive(at: away.addingTimeInterval(1))
        #expect(state.isRelocked)
    }

    @Test func faceIDUnlocksTheRelockedApp() async throws {
        let state = makeState(biometrics: StubBiometrics())
        state.finishLoading()
        state.signIn(accountID: ravi)
        try state.completePinSetup(pin: pin, useBiometrics: true)
        let away = Date(timeIntervalSince1970: 1_000)
        state.didEnterBackground(at: away)
        state.didBecomeActive(at: away.addingTimeInterval(3_600))
        #expect(await state.unlockWithBiometrics())
        #expect(state.isOpen)
    }

    @Test func startsInLoading() {
        #expect(makeState().phase == .loading)
    }

    @Test func newUserGoesFromLoadingToLogin() {
        let state = makeState()
        state.finishLoading()
        #expect(state.phase == .signedOut)
    }

    @Test func signInRequiresCreatingAPin() throws {
        let state = makeState()
        state.finishLoading()
        state.signIn(accountID: ravi)
        #expect(state.phase == .pinSetup)

        try state.completePinSetup(pin: pin, useBiometrics: false)
        #expect(state.phase == .main)
    }

    @Test func weakPinIsRejectedDuringSetup() {
        let state = makeState()
        state.finishLoading()
        state.signIn(accountID: ravi)
        #expect(throws: PinVaultError.unacceptablePin) {
            try state.completePinSetup(pin: "123456", useBiometrics: false)
        }
        #expect(state.phase == .pinSetup)
    }

    @Test func cannotSignInWhileLoading() {
        let state = makeState()
        state.signIn(accountID: ravi)
        #expect(state.phase == .loading)
        #expect(!state.isSignedIn)
    }

    @Test func relaunchAsksForThePin() throws {
        _ = try signedInState()

        let relaunched = makeState()
        #expect(relaunched.phase == .loading)
        relaunched.finishLoading()
        #expect(relaunched.phase == .locked)
    }

    @Test func relaunchWithoutPinAsksToCreateOne() {
        let state = makeState()
        state.finishLoading()
        state.signIn(accountID: ravi)

        let relaunched = makeState()
        relaunched.finishLoading()
        #expect(relaunched.phase == .pinSetup)
    }

    @Test func correctPinUnlocks() throws {
        _ = try signedInState()
        let relaunched = makeState()
        relaunched.finishLoading()

        #expect(relaunched.unlock(with: pin) == .correct)
        #expect(relaunched.phase == .main)
    }

    @Test func wrongPinStaysLocked() throws {
        _ = try signedInState()
        let relaunched = makeState()
        relaunched.finishLoading()

        #expect(relaunched.unlock(with: "000001") == .incorrect(attemptsRemaining: 4))
        #expect(relaunched.phase == .locked)
    }

    @Test func tooManyWrongPinsSignOut() throws {
        _ = try signedInState()
        let relaunched = makeState()
        relaunched.finishLoading()

        for _ in 0..<4 { _ = relaunched.unlock(with: "000001") }
        #expect(relaunched.unlock(with: "000001") == .lockedOut)
        #expect(relaunched.phase == .signedOut)
        #expect(!relaunched.isSignedIn)
    }

    @Test func biometricsUnlockOnlyWhenEnabled() async throws {
        let state = makeState()
        state.finishLoading()
        state.signIn(accountID: ravi)
        try state.completePinSetup(pin: pin, useBiometrics: true)

        let relaunched = makeState()
        relaunched.finishLoading()
        #expect(relaunched.canUnlockWithBiometrics)
        #expect(await relaunched.unlockWithBiometrics())
        #expect(relaunched.phase == .main)
    }

    @Test func failedBiometricsStayLocked() async throws {
        let state = makeState()
        state.finishLoading()
        state.signIn(accountID: ravi)
        try state.completePinSetup(pin: pin, useBiometrics: true)

        let relaunched = makeState(biometrics: StubBiometrics(succeeds: false))
        relaunched.finishLoading()
        #expect(await !relaunched.unlockWithBiometrics())
        #expect(relaunched.phase == .locked)
    }

    @Test func biometricsDoNotUnlockWhenNotEnabled() async throws {
        _ = try signedInState()
        let relaunched = makeState()
        relaunched.finishLoading()
        #expect(!relaunched.canUnlockWithBiometrics)
        #expect(await !relaunched.unlockWithBiometrics())
        #expect(relaunched.phase == .locked)
    }

    @Test func signOutKeepsThePinForTheSameAccount() throws {
        let state = try signedInState()
        state.signOut()
        #expect(state.phase == .signedOut)

        let relaunched = makeState()
        relaunched.finishLoading()
        #expect(relaunched.phase == .signedOut)

        relaunched.signIn(accountID: ravi)
        #expect(relaunched.phase == .main)

        let nextLaunch = makeState()
        nextLaunch.finishLoading()
        #expect(nextLaunch.unlock(with: pin) == .correct)
    }

    @Test func anotherAccountMustCreateItsOwnPin() throws {
        let state = try signedInState()
        state.signOut()

        state.signIn(accountID: gianna)
        #expect(state.phase == .pinSetup)

        try state.completePinSetup(pin: "908172", useBiometrics: false)
        let relaunched = makeState()
        relaunched.finishLoading()
        #expect(relaunched.unlock(with: pin) == .incorrect(attemptsRemaining: 4))
        #expect(relaunched.unlock(with: "908172") == .correct)
    }

    @Test func unknownAccountMustCreateAPin() throws {
        let state = try signedInState()
        state.signOut()

        state.signIn(accountID: nil)
        #expect(state.phase == .pinSetup)
    }

    @Test func forgottenPinRequiresANewOneAfterSignIn() throws {
        let state = try signedInState()
        let relaunched = makeState()
        relaunched.finishLoading()
        relaunched.forgetPin()
        #expect(relaunched.phase == .signedOut)

        relaunched.signIn(accountID: ravi)
        #expect(relaunched.phase == .pinSetup)
        _ = state
    }

    @Test func lockoutRequiresANewPinAfterSignIn() throws {
        _ = try signedInState()
        let relaunched = makeState()
        relaunched.finishLoading()
        for _ in 0..<5 { _ = relaunched.unlock(with: "000001") }
        #expect(relaunched.phase == .signedOut)

        relaunched.signIn(accountID: ravi)
        #expect(relaunched.phase == .pinSetup)
    }

    @Test func aSessionThatEndedElsewhereAsksToSignInAgain() async throws {
        let state = try signedInState(session: .ended)
        state.conversationToOpen = "chat-1"
        await state.checkSession()
        #expect(state.phase == .sessionEnded)
        #expect(!state.isSignedIn)
        #expect(state.conversationToOpen == nil)

        state.signInAgain()
        #expect(state.phase == .signedOut)
        state.signIn(accountID: ravi)
        #expect(state.phase == .main)
    }

    @Test func aSessionThatEndedWhileLockedSkipsThePin() async throws {
        _ = try signedInState()
        let relaunched = makeState(session: .ended)
        relaunched.finishLoading()
        #expect(relaunched.phase == .locked)
        await relaunched.checkSession()
        #expect(relaunched.phase == .sessionEnded)
    }

    @Test func noAnswerKeepsYouSignedIn() async throws {
        let state = try signedInState(session: .unknown)
        await state.checkSession()
        #expect(state.phase == .main)
        #expect(state.isSignedIn)
    }

    @Test func nothingIsCheckedWhenSignedOut() async {
        let state = makeState(session: .ended)
        state.finishLoading()
        await state.checkSession()
        #expect(state.phase == .signedOut)
    }
}
