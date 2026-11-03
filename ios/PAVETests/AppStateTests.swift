import Foundation
import Testing
@testable import PAVE

@MainActor
struct AppStateTests {
    private let defaults = UserDefaults(suiteName: "AppStateTests-\(UUID().uuidString)")!

    @Test func startsInLoading() {
        #expect(AppState(defaults: defaults).phase == .loading)
    }

    @Test func newUserGoesFromLoadingToLogin() {
        let state = AppState(defaults: defaults)
        state.finishLoading()
        #expect(state.phase == .signedOut)
    }

    @Test func signInOpensMainAndIsRemembered() {
        let state = AppState(defaults: defaults)
        state.finishLoading()
        state.signIn()
        #expect(state.phase == .main)

        let relaunched = AppState(defaults: defaults)
        #expect(relaunched.phase == .loading)
        relaunched.finishLoading()
        #expect(relaunched.phase == .main)
    }

    @Test func signOutIsRememberedOnRelaunch() {
        let state = AppState(defaults: defaults)
        state.finishLoading()
        state.signIn()
        state.signOut()
        #expect(state.phase == .signedOut)

        let relaunched = AppState(defaults: defaults)
        relaunched.finishLoading()
        #expect(relaunched.phase == .signedOut)
    }

    @Test func cannotSignInWhileLoading() {
        let state = AppState(defaults: defaults)
        state.signIn()
        #expect(state.phase == .loading)
        #expect(!state.isSignedIn)
    }
}
