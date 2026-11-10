import PAVECore
import SwiftUI

/// Adding something to the vault or changing it. What you add yourself is shown as "Niet bevestigd" until a school or
/// employer confirms it; the app can never mark it as confirmed.
struct VaultItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultModel.self) private var model
    let itemID: String?
    private let initialDraft: VaultItemDraft
    @State private var draft: VaultItemDraft
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var confirmsDiscard = false
    @State private var showsProblem = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, organisation, location, description }

    init(item: VaultItem) {
        itemID = item.id
        initialDraft = VaultItemDraft(item: item)
        _draft = State(initialValue: initialDraft)
    }

    init(category: VaultCategory, folderID: String?) {
        itemID = nil
        initialDraft = VaultItemDraft(category: category, folderID: folderID)
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Soort", selection: $draft.category) {
                        ForEach(VaultCategory.allCases) { category in
                            Text(category.singularTitle).tag(category)
                        }
                    }
                    TextField("Titel, bijvoorbeeld Propedeuse HBO-ICT", text: $draft.title, axis: .vertical)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .accessibilityLabel("Titel")
                } footer: {
                    if showsProblem, let problem = draft.problem, problem != .endBeforeStart {
                        problemText(problem)
                    }
                }

                Section("Waar") {
                    TextField("School, opleiding of werkgever", text: $draft.organisationName)
                        .textContentType(.organizationName)
                        .focused($focusedField, equals: .organisation)
                        .accessibilityLabel("Organisatie")
                    TextField("Plaats", text: $draft.organisationLocation)
                        .textContentType(.addressCity)
                        .focused($focusedField, equals: .location)
                        .accessibilityLabel("Plaats")
                }

                Section {
                    if draft.category.hasPeriod {
                        optionalDate("Begonnen", day: $draft.startDate)
                        Toggle("Ik doe dit nog", isOn: $draft.isCurrent.animation())
                            .tint(.brandGreen)
                        if !draft.isCurrent {
                            optionalDate("Gestopt", day: $draft.endDate)
                        }
                    } else {
                        optionalDate("Behaald op", day: $draft.issuedOn)
                    }
                } header: {
                    Text("Wanneer")
                } footer: {
                    if showsProblem, draft.problem == .endBeforeStart {
                        problemText(.endBeforeStart)
                    }
                }

                Section("Omschrijving") {
                    TextField("Wat heb je gedaan of geleerd?", text: $draft.description, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedField, equals: .description)
                        .accessibilityLabel("Omschrijving")
                }

                if !model.folders.isEmpty {
                    Section {
                        Picker("Map", selection: $draft.folderID) {
                            Text("Geen map").tag(String?.none)
                            ForEach(model.folders) { folder in
                                Text(folder.name).tag(Optional(folder.id))
                            }
                        }
                    }
                }

                if itemID == nil {
                    Section {
                        Label {
                            Text("Je voegt dit zelf toe. Het staat als “Niet bevestigd” in je kluis tot een school of werkgever het bevestigt. Een bestand toevoegen kan binnenkort.")
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                        } icon: {
                            Image(.iconInformationCircle)
                                .renderingMode(.template)
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(itemID == nil ? "Nieuw in je kluis" : "Aanpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") {
                        if draft == initialDraft { dismiss() } else { confirmsDiscard = true }
                    }
                    .confirmationDialog("Wijzigingen weggooien?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                        Button("Weggooien", role: .destructive) { dismiss() }
                        Button("Verder bewerken", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Bewaren", action: save)
                            .fontWeight(.semibold)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || draft != initialDraft)
            .onAppear {
                if itemID == nil { focusedField = .title }
            }
            .alert("Niet bewaard", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .tint(.brandGreen)
    }

    private func optionalDate(_ title: String, day: Binding<VaultDay?>) -> some View {
        HStack {
            if let current = day.wrappedValue {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { current.date() },
                        set: { day.wrappedValue = VaultDay($0) }
                    ),
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "nl_NL"))
                Button {
                    day.wrappedValue = nil
                } label: {
                    Image(.iconXMark)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) wissen")
            } else {
                Text(title)
                Spacer()
                Button("Datum kiezen") { day.wrappedValue = VaultDay(.now) }
            }
        }
    }

    private func problemText(_ problem: VaultItemDraft.Problem) -> some View {
        Text(VaultMessages.problem(problem))
            .textStyle(.caption)
            .foregroundStyle(Color.critical)
    }

    private func save() {
        guard draft.problem == nil else {
            withAnimation { showsProblem = true }
            PaveHaptics.error()
            if draft.problem == .missingTitle || draft.problem == .titleTooLong { focusedField = .title }
            return
        }
        focusedField = nil
        isSaving = true
        Task {
            let saved = await model.save(draft, itemID: itemID)
            isSaving = false
            if saved {
                dismiss()
            } else {
                saveError = model.problem
                model.problem = nil
            }
        }
    }
}

#Preview {
    VaultItemEditor(category: .internships, folderID: nil)
        .environment(VaultModel(previewContents: .preview))
}
