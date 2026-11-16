import SwiftUI

struct AuthReturnButton: View {
    var title = "Terug naar inloggen"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(.iconArrowLeft)
                    .resizable()
                    .paveIconFrame(18)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
    }
}

#Preview {
    AuthReturnButton {}
}
