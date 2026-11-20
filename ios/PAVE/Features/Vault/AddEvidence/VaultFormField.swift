import SwiftUI

/// A label above a bordered field, with a green star when it is required and a message below when it is missing. A
/// field Ayla filled in says so below it ("Door Ayla · pagina 1"), until the user changes it.
struct VaultFormField<Content: View>: View {
    let title: String
    var isRequired = true
    var error: String?
    var minHeight: CGFloat = 44
    var note: String?
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
                .background(Color.panel, in: .rect(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(error == nil ? Color.railBorder : .critical, lineWidth: error == nil ? 1 : 1.5)
                }
                .accessibilityLabel(isRequired ? "\(title), verplicht" : title)
                .accessibilityHint(note.map(VaultAylaNote.spoken) ?? "")
            if let error {
                PaveInlineError(message: error)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let note {
                VaultAylaNote(text: note)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: error)
        .animation(.easeOut(duration: 0.2), value: note)
    }
}

#Preview {
    VStack(spacing: 20) {
        VaultFormField(title: "Titel") { TextField("", text: .constant("")) }
        VaultFormField(title: "Organisatie / school", error: "Vul de organisatie of school in.") { TextField("", text: .constant("")) }
    }
    .padding(24)
}
