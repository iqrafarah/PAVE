import SwiftUI

/// The splash, then either Ayla or the request to sign in on the iPhone.
struct WatchRootView: View {
    @State private var sessions = WatchSessionStore()
    @State private var model: WatchAylaModel?
    @State private var isLoading = true
    @State private var newCode: WatchSharedCode?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if isLoading {
                PaveSplashView()
            } else if let model, !model.isSignedOut {
                NavigationStack {
                    WatchVoiceView(model: model)
                }
                .environment(sessions)
                // The colour of the iPhone's theme, in the orb and everything around it.
                .environment(\.paveOrbPalette, WatchPreferences.shared.orbPalette)
                .tint(WatchPreferences.shared.accentColor)
                // A code just approved on the iPhone comes up by itself.
                .sheet(item: Binding(get: { newCode }, set: { if $0 == nil { newCode = nil } })) { code in
                    WatchSharedCodeView(code: code)
                }
            } else {
                WatchSignedOutView(needsConnecting: sessions.needsConnecting)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isLoading)
        .onChange(of: sessions.sharedCode) { _, code in newCode = code?.isValid == true ? code : nil }
        // Lowering your wrist only dims the screen, so Ayla finishes her answer; leaving the app stops her.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model?.pause() }
        }
        .task {
            sessions.start()
            let model = WatchAylaModel(sessions: sessions)
            self.model = model
            WatchLaunchRequest.onListen = { model.listenFromShortcut() }
            // Coming from Siri: skip most of the splash and listen straight away.
            let fromShortcut = WatchLaunchRequest.takePending()
            try? await Task.sleep(for: .seconds(fromShortcut ? 0.6 : 1.5))
            isLoading = false
            if fromShortcut { model.listenFromShortcut() }
        }
    }
}

#Preview {
    WatchRootView()
}
