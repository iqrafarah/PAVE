import SwiftUI

/// A label above a bordered field, with a green star when it is required and a message below when it is missing.
struct VaultFormField<Content: View>: View {
    let title: String
    var isRequired = true
    var error: String?
    var minHeight: CGFloat = 44
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text(title) + (isRequired ? Text(" *").foregroundStyle(Color.paveAccent) : Text("")))
                .textStyle(.label)
                .foregroundStyle(Color.ink)
                .accessibilityHidden(true)
            content
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .background(Color.white, in: .rect(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(error == nil ? Color.railBorder : .critical, lineWidth: error == nil ? 1 : 1.5)
                }
                .accessibilityLabel(isRequired ? "\(title), verplicht" : title)
            if let error {
                PaveInlineError(message: error)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: error)
    }
}

#Preview {
    VStack(spacing: 20) {
        VaultFormField(title: "Titel") { TextField("", text: .constant("")) }
        VaultFormField(title: "Organisatie / school", error: "Vul de organisatie of school in.") { TextField("", text: .constant("")) }
    }
    .padding(24)
}
