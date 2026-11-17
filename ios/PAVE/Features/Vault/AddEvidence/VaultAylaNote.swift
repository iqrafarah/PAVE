import SwiftUI

/// A short line with Ayla's pixel A, under something she filled in or chose: "Door Ayla · pagina 1".
struct VaultAylaNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            AylaLetter(color: .paveAccent)
                .scaleEffect(0.6)
                .paveIconScale()
                .paveIconFrame(10.5)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                .accessibilityHidden(true)
            Text(text)
                .textStyle(.meta)
                .foregroundStyle(Color.paveAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(text))
    }

    /// VoiceOver reads the dot as a word; a comma gives the same short pause.
    static func spoken(_ text: String) -> String {
        text.replacingOccurrences(of: " · ", with: ", ")
    }
}

#Preview {
    VaultAylaNote(text: "Door Ayla · pagina 1")
        .padding()
}
