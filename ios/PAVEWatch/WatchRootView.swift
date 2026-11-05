import SwiftUI

struct WatchRootView: View {
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                PaveSplashView()
            } else {
                VStack(spacing: 4) {
                    Text("Ayla")
                        .font(.headline)
                    Text("Komt binnenkort.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isLoading)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            isLoading = false
        }
    }
}

#Preview {
    WatchRootView()
}
