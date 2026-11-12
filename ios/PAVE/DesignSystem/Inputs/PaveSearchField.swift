import SwiftUI

/// A glass search field with a magnifying glass and a button to clear it.
struct PaveSearchField: View {
    @Binding var text: String
    let prompt: String
    var isFocused: FocusState<Bool>.Binding?

    var body: some View {
        HStack(spacing: 13) {
            Image(.iconSearch)
                .renderingMode(.template)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Color.inkMuted))
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(.iconPlus)
                        .renderingMode(.template)
                        .resizable()
                        .paveIconFrame(11)
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 32, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Zoekveld leegmaken")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(height: 40)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

#Preview {
    @Previewable @State var text = ""
    PaveSearchField(text: $text, prompt: "Zoeken")
        .padding()
        .background(Color.canvas)
}

private extension View {
    @ViewBuilder
    func focused(_ binding: FocusState<Bool>.Binding?) -> some View {
        if let binding { focused(binding) } else { self }
    }
}
