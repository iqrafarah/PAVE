import SwiftUI

struct LoadingView: View {
    @Environment(AppState.self) private var appState

    var minimumDuration: Duration = .seconds(1.5)

    var body: some View {
        PaveSplashView(accent: .paveAccent)
            .task {
                try? await Task.sleep(for: minimumDuration)
                appState.finishLoading()
            }
    }
}

#Preview {
    LoadingView(minimumDuration: .seconds(3600))
        .environment(AppState())
}
