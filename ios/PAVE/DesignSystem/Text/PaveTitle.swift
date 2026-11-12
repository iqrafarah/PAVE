import SwiftUI

/// The screen title in the middle of the header: PAVE's pixel slash and a word, such as "/ Ayla".
struct PaveTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3.3) {
            PaveMark(count: 5, size: 5.333, color: .paveAccent)
            Text(text)
                .textStyle(.aylaTitle)
                .foregroundStyle(Color.paveAccent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(spacing: 24) {
        PaveTitle("Ayla")
        PaveTitle("Chats")
        PaveTitle("Kluis")
    }
    .padding()
}
