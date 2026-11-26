import PAVECore
import SwiftUI

/// Applying somewhere PAVE did not find: a vacancy from elsewhere, or an open application to a company. Only the
/// company is needed; the studio opens next, as from a vacancy.
struct ApplicationNewSheet: View {
    let onStart: (Vacancy) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var own = OwnApplication()
    @State private var triedToStart = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case company, title, city, link, text }

    private var companyError: String? { triedToStart && own.problem == .noCompany ? ApplyMessages.ownCompanyMissing : nil }
    private var linkError: String? { own.problem == .badLink && focus != .link ? ApplyMessages.ownLinkBad : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(ApplyMessages.newApplicationIntro)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    VaultFormField(title: ApplyMessages.ownCompany, error: companyError) {
                        line($own.company, prompt: ApplyMessages.ownCompanyPrompt, field: .company)
                            .textContentType(.organizationName)
                    }
                    VaultFormField(title: ApplyMessages.ownTitle, isRequired: false) {
                        line($own.title, prompt: ApplyMessages.ownTitlePrompt, field: .title)
                            .textContentType(.jobTitle)
                    }
                    VaultFormField(title: ApplyMessages.ownCity, isRequired: false) {
                        line($own.city, prompt: ApplyMessages.ownCityPrompt, field: .city)
                            .textContentType(.addressCity)
                    }
                    VaultFormField(title: ApplyMessages.ownLink, isRequired: false, error: linkError) {
                        line($own.link, prompt: ApplyMessages.ownLinkPrompt, field: .link)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    VaultFormField(title: ApplyMessages.ownText, isRequired: false, minHeight: 120) {
                        TextField("", text: $own.text, prompt: Text(ApplyMessages.ownTextPrompt).foregroundStyle(Color.inkMuted), axis: .vertical)
                            .lineLimit(4...12)
                            .textStyle(.input)
                            .foregroundStyle(Color.ink)
                            .focused($focus, equals: .text)
                            .padding(.vertical, 12)
                    }
                    Text(ApplyMessages.ownTextNote)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -12)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas)
            .safeAreaInset(edge: .bottom) {
                PavePrimaryButton(title: ApplyMessages.ownStart) { start() }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .background(Color.canvas)
            }
            .navigationTitle(ApplyMessages.newApplication)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SharingMessages.cancel) { dismiss() }
                }
            }
            .onAppear { focus = .company }
        }
        .interactiveDismissDisabled(own != OwnApplication())
    }

    private func line(_ text: Binding<String>, prompt: String, field: Field) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(Color.inkMuted))
            .textStyle(.input)
            .foregroundStyle(Color.ink)
            .focused($focus, equals: field)
            .submitLabel(.next)
            .onSubmit { focus = next(after: field) }
    }

    private func next(after field: Field) -> Field? {
        switch field {
        case .company: .title
        case .title: .city
        case .city: .link
        case .link: .text
        case .text: nil
        }
    }

    private func start() {
        triedToStart = true
        switch own.problem {
        case .noCompany:
            PaveHaptics.error()
            focus = .company
        case .badLink:
            PaveHaptics.error()
            focus = .link
        case nil:
            PaveHaptics.success()
            let vacancy = own.vacancy()
            dismiss()
            onStart(vacancy)
        }
    }
}
