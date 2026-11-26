import PAVECore
import SwiftUI

/// Where an application comes from, as a small tag on its row: Ayla, Zelf or Beurs.
struct ApplicationSourceTag: View {
    let source: ApplicationSource

    var body: some View {
        Text(ApplyMessages.source(source))
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.canvas, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}

#Preview {
    HStack {
        ForEach(ApplicationSource.allCases, id: \.self) { ApplicationSourceTag(source: $0) }
    }
    .padding()
}
