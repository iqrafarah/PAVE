import PAVECore
import SwiftUI

/// Changing the chosen block by hand, with Ayla's help on running text.
struct ApplicationBlockEditor: View {
    let model: ApplicationStudioModel
    let block: ApplicationBlock

    @State private var confirmsRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // A block of one field has that field's name already; a heading on top would say it twice.
            if hasHeading {
                Text(title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            fields
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasHeading: Bool {
        switch block {
        case .personal, .entry, .closing: true
        default: false
        }
    }

    private var title: String {
        switch block {
        case .personal: ApplyMessages.personal
        case .profile: ApplyMessages.profileHeading
        case .entry(let id): model.entry(id)?.title ?? ApplyMessages.entryTitle
        case .skills: ApplyMessages.skillsHeading
        case .salutation: ApplyMessages.salutation
        case .paragraph: ApplyMessages.paragraph
        case .closing: ApplyMessages.closingLine
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch block {
        case .personal:
            field(ApplyMessages.name, text: binding(\.cv.name))
            field(ApplyMessages.headline, text: binding(\.cv.headline), prompt: ApplyMessages.headlineHint)
            field(ApplyMessages.email, text: binding(\.cv.email), keyboard: .emailAddress, content: .emailAddress)
            field(ApplyMessages.phone, text: binding(\.cv.phone), keyboard: .phonePad, content: .telephoneNumber)
            field(ApplyMessages.city, text: binding(\.cv.city), content: .addressCity)
        case .profile:
            longField(ApplyMessages.profileHeading, text: binding(\.cv.profile))
            ApplicationRewriteBar(model: model, block: block)
        case .entry(let id):
            if let entry = model.entry(id) {
                ApplicationSourceRow(item: model.item(entry.sourceItemID))
                field(ApplyMessages.entryTitle, text: entryBinding(id, \.title))
                field(ApplyMessages.entryOrganisation, text: entryBinding(id, \.organisation))
                field(ApplyMessages.entryPeriod, text: entryBinding(id, \.period))
                longField(ApplyMessages.entryDescription, text: entryBinding(id, \.description))
                Toggle(ApplyMessages.showOnCV, isOn: Binding(get: { model.entry(id)?.isVisible ?? true }, set: { value in model.updateEntry(id) { $0.isVisible = value } }))
                    .textStyle(.bodyMedium)
                    .tint(.paveAccentFill)
            }
        case .skills:
            longField(ApplyMessages.skillsHeading, text: Binding(
                get: { model.draft.cv.skills.joined(separator: "\n") },
                set: { text in model.update { $0.cv.skills = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } } }
            ), note: ApplyMessages.skillsHint)
        case .salutation:
            field(ApplyMessages.salutation, text: binding(\.letter.salutation))
        case .paragraph(let id):
            if let index = model.paragraphIndex(id) {
                longField(ApplyMessages.paragraph, text: Binding(
                    get: { model.paragraphIndex(id).map { model.draft.letter.paragraphs[$0].text } ?? "" },
                    set: { text in model.update { draft in if let i = draft.letter.paragraphs.firstIndex(where: { $0.id == id }) { draft.letter.paragraphs[i].text = text } } }
                ))
                ForEach(model.draft.letter.paragraphs[index].sourceItemIDs, id: \.self) { source in
                    ApplicationSourceRow(item: model.item(source))
                }
                ApplicationRewriteBar(model: model, block: block)
                Button(ApplyMessages.removeParagraph, role: .destructive) { confirmsRemoval = true }
                    .textStyle(.link)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
                    .confirmationDialog(ApplyMessages.removeParagraphQuestion, isPresented: $confirmsRemoval, titleVisibility: .visible) {
                        Button(ApplyMessages.removeParagraph, role: .destructive) { model.removeParagraph(id) }
                        Button(ApplyMessages.cancel, role: .cancel) {}
                    }
            }
        case .closing:
            field(ApplyMessages.closingLine, text: binding(\.letter.closing))
            field(ApplyMessages.signature, text: binding(\.letter.signature))
        }
    }

    private func binding(_ path: WritableKeyPath<ApplicationDraft, String>) -> Binding<String> {
        Binding(get: { model.draft[keyPath: path] }, set: { value in model.update { $0[keyPath: path] = value } })
    }

    private func entryBinding(_ id: String, _ path: WritableKeyPath<CVEntry, String>) -> Binding<String> {
        Binding(get: { model.entry(id)?[keyPath: path] ?? "" }, set: { value in model.updateEntry(id) { $0[keyPath: path] = value } })
    }

    private func field(_ title: String, text: Binding<String>, prompt: String? = nil, keyboard: UIKeyboardType = .default, content: UITextContentType? = nil) -> some View {
        VaultFormField(title: title, isRequired: false) {
            TextField("", text: text, prompt: prompt.map { Text($0).foregroundStyle(Color.inkMuted) })
                .textStyle(.input)
                .foregroundStyle(Color.ink)
                .keyboardType(keyboard)
                .textContentType(content)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
        }
    }

    private func longField(_ title: String, text: Binding<String>, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VaultFormField(title: title, isRequired: false, minHeight: 120) {
                TextField("", text: text, axis: .vertical)
                    .lineLimit(5...14)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .padding(.vertical, 10)
            }
            if let note {
                Text(note)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }
}
