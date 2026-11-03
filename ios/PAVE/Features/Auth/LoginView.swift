import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Text("Inloggen")
                .font(.title.bold())
            Text("Demo: er wordt niet echt ingelogd.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Doorgaan als Ravi") {
                appState.signIn()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
