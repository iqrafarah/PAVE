import SwiftUI

/// Above the main button of a sharing sheet: what went wrong, or else why the button does not work yet.
struct ShareBottomNote: View {
    let error: String?
    let reason: String?

    var body: some View {
        Group {
            if let error {
                PaveInlineError(message: error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let reason {
                Text(reason)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.2), value: error)
        .animation(.easeOut(duration: 0.2), value: reason)
    }
}
