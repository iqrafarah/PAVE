import PAVECore
import SwiftUI

/// Verification request form backed by the trusted organisation directory.
struct VaultRequestConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(VaultModel.self) private var vault
    let item: VaultItem
    let documentCount: Int
    var onShowMenu: (() -> Void)?
    var onSend: ((VaultConfirmationRequest) async -> String?)?

    private enum Choice: String, Identifiable {
        case organization, location, department, contactType, contact
        var id: String { rawValue }
        var title: String {
            switch self {
            case .organization: "Organisatie kiezen"
            case .location: "Vestiging kiezen"
            case .department: "Afdeling of opleiding kiezen"
            case .contactType: "Functie kiezen"
            case .contact: "Contactpersoon kiezen"
            }
        }
    }

    @State private var request: VaultConfirmationRequest
    @State private var organizations: [VaultValidationOrganization] = []
    @State private var locations: [VaultValidationLocation] = []
    @State private var departments: [VaultValidationDepartment] = []
    @State private var contacts: [VaultValidationContact] = []
    @State private var choice: Choice?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isFinished = false
    @State private var isSending = false
    @State private var isDirty = false
    @State private var showsMissing = false
    @State private var confirmsDiscard = false
    @State private var sendError: String?
    @State private var directoryError: String?
    @State private var evidenceLogo: VaultLogoLook?

    init(item: VaultItem, documentCount: Int, onShowMenu: (() -> Void)? = nil, onSend: ((VaultConfirmationRequest) async -> String?)? = nil) {
        self.item = item
        self.documentCount = documentCount
        self.onShowMenu = onShowMenu
        self.onSend = onSend
        _request = State(initialValue: VaultConfirmationRequest(item: item))
    }

    private var hasChanges: Bool { !isFinished && isDirty }

    var body: some View {
        NavigationStack {
            Group {
                if isFinished { successView.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing))) }
                else { form.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading))) }
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Kluis", onShowMenu: onShowMenu)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
        .animation(.snappy(duration: 0.35), value: isFinished)
        .tint(.brandGreen)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheetDismissGuard(isBlocked: hasChanges) { confirmsDiscard = true }
        .confirmationDialog(VaultMessages.discardRequestTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Weggooien", role: .destructive) { dismiss() }
            Button("Verder met invullen", role: .cancel) {}
        }
        .sheet(item: $choice) { selectedChoice in
            choiceSheet(selectedChoice)
                .paveSheet()
        }
        .task(id: item.id) {
            evidenceLogo = nil
            if let logo = vault.logo(of: item) { evidenceLogo = await vault.look(of: logo) }
            await loadOrganizations()
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verificatie aanvraag").textStyle(.calloutTitle).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
                        Text("Laat je gegevens bevestigen.").textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                    }
                    if let sendError { PaveNotice(message: sendError) }
                    if let directoryError { PaveNotice(message: directoryError) }
                    evidenceSummary

                    VStack(alignment: .leading, spacing: 22) {
                        pickerField(title: "Naam bedrijf", value: request.organization?.name, placeholder: "Kies een organisatie", error: error(.organisation)) { searchText = ""; choice = .organization }
                        pickerField(title: "Locatie van het bedrijf", value: request.location?.city, placeholder: "Typ of kies een vestigingsplaats", error: error(.location)) { searchText = ""; choice = .location }
                        if request.organization?.kind == "school", !departments.isEmpty {
                            pickerField(title: "Afdeling of opleiding", value: request.department?.name, placeholder: "Kies een afdeling of sla over") { searchText = ""; choice = .department }
                        }
                        pickerField(title: "Type contactpersoon", value: request.contactType, placeholder: "Kies bijvoorbeeld docent of stagebegeleider", error: error(.contactType)) { searchText = ""; choice = .contactType }
                        pickerField(title: "Betreffend persoon.", value: request.contact.map(\.name), placeholder: "Kies een persoon", error: error(.contact), isEnabled: request.contactType != nil) { searchText = ""; choice = .contact }
                    }
                    .padding(20)
                    .background(Color.white, in: .rect(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 18)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            PavePrimaryButton(title: isSending ? "Aanvraag versturen…" : "Aanvraag versturen") { send() }
                .disabled(isSending || isLoading)
                .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 4).frame(maxWidth: 440)
            Text("Je aanvraag gaat naar de gekozen contactpersoon of naar de beoordelaars van de organisatie.")
                .textStyle(.caption).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center)
                .frame(maxWidth: 320).padding(.horizontal, 28).padding(.top, 10).padding(.bottom, 12)
        }
    }

    private func pickerField(title: String, value: String?, placeholder: String, error: String? = nil, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textStyle(.label).foregroundStyle(Color.ink)
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(value ?? placeholder).textStyle(.input).foregroundStyle(value == nil ? Color.inkMuted : Color.ink).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(.iconChevronDown).resizable().scaledToFit().frame(width: 15, height: 15).foregroundStyle(Color.ink)
                }
                .padding(.leading, 12).padding(.trailing, 14).frame(height: 48)
                .background(Color.white, in: .rect(cornerRadius: 11))
                .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.cardBorder) }
                .contentShape(.rect(cornerRadius: 11))
            }
            .buttonStyle(.pave).disabled(isLoading || !isEnabled || (title != "Naam bedrijf" && request.organization == nil) || (title != "Naam bedrijf" && title != "Locatie van het bedrijf" && request.location == nil))
            .accessibilityLabel("\(title): \(value ?? placeholder)")
            if let error { PaveInlineError(message: error) }
        }
    }

    private func choiceSheet(_ selected: Choice) -> some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if filteredChoiceCount(selected) == 0 {
                    ContentUnavailableView(emptyChoiceTitle(selected), systemImage: "person.2", description: Text(emptyChoiceDescription(selected)))
                } else {
                    List {
                        switch selected {
                        case .organization:
                            ForEach(["school", "company"], id: \.self) { kind in
                                let rows = filteredOrganizations.filter { $0.kind == kind }
                                if !rows.isEmpty {
                                    Section(kind == "school" ? "School of opleiding" : "Bedrijf") {
                                        ForEach(rows) { organization in
                                            choiceRow(organization.name, detail: nil, selected: request.organization?.id == organization.id) { Task { await select(organization) } }
                                        }
                                    }
                                }
                            }
                        case .location:
                            ForEach(filteredLocations) { location in choiceRow(location.city, detail: nil, selected: request.location?.id == location.id) { Task { await select(location) } } }
                        case .department:
                            choiceRow("Overslaan", detail: "Geen afdeling of opleiding kiezen", selected: request.department == nil) { isDirty = true; request.department = nil; choice = nil; Task { await loadContacts() } }
                            ForEach(filteredDepartments) { department in choiceRow(department.name, detail: nil, selected: request.department?.id == department.id) { Task { await select(department) } } }
                        case .contactType:
                            ForEach(filteredContactTypes, id: \.self) { type in
                                choiceRow(type, detail: "Filter contactpersonen op functie", selected: request.contactType == type) {
                                    isDirty = true
                                    request.contactType = type
                                    request.contact = nil
                                    choice = nil
                                }
                            }
                        case .contact:
                            ForEach(filteredContacts) { contact in choiceRow(contact.name, detail: contact.jobTitle, selected: request.contact?.id == contact.id) { isDirty = true; request.contact = contact; choice = nil } }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(selected.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Zoeken")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Gereed") { choice = nil } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func choiceRow(_ title: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).foregroundStyle(Color.ink)
                    if let detail, !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(Color.inkMuted) }
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Color.brandGreen) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var filteredOrganizations: [VaultValidationOrganization] { organizations.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) } }
    private var filteredLocations: [VaultValidationLocation] { locations.filter { searchText.isEmpty || $0.city.localizedCaseInsensitiveContains(searchText) } }
    private var filteredDepartments: [VaultValidationDepartment] { departments.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) } }
    private var contactTypes: [String] { Array(Set(contacts.map(contactTypeName))).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    private var filteredContactTypes: [String] { contactTypes.filter { searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText) } }
    private var filteredContacts: [VaultValidationContact] { contacts.filter { contactTypeName($0) == request.contactType && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)) } }

    private func contactTypeName(_ contact: VaultValidationContact) -> String {
        let value = contact.jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? "Overig"
    }

    private func filteredChoiceCount(_ selected: Choice) -> Int {
        switch selected {
        case .organization: return filteredOrganizations.count
        case .location: return filteredLocations.count
        case .department: return filteredDepartments.count + 1
        case .contactType: return filteredContactTypes.count
        case .contact: return filteredContacts.count
        }
    }
    private func emptyChoiceTitle(_ selected: Choice) -> String {
        switch selected {
        case .organization: return "Geen organisaties gevonden"
        case .location: return "Geen vestigingen gevonden"
        case .department: return "Geen afdelingen gevonden"
        case .contactType: return "Geen functies gevonden"
        case .contact: return "Geen contactpersonen gevonden"
        }
    }
    private func emptyChoiceDescription(_ selected: Choice) -> String {
        switch selected {
        case .organization: return "Probeer een andere zoekopdracht."
        case .location: return "Er zijn nog geen vestigingen voor deze organisatie ingesteld."
        case .department: return "Er zijn geen afdelingen of opleidingen voor deze vestiging."
        case .contactType: return "Er zijn geen contactfuncties voor deze keuze."
        case .contact: return "Er zijn geen actieve contactpersonen voor deze keuze."
        }
    }

    private func loadOrganizations() async {
        isLoading = true; defer { isLoading = false }
        do {
            organizations = try await vault.validationOrganizations()
            if let name = item.organisationName, let match = organizations.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                request.organization = match
                await loadLocations()
            }
        } catch { directoryError = "De organisaties konden niet worden geladen. Probeer het opnieuw." }
    }

    private func loadLocations() async {
        guard let organization = request.organization else { return }
        do {
            locations = try await vault.validationLocations(organizationID: organization.id)
            if let city = item.organisationLocation, let match = locations.first(where: { $0.city.localizedCaseInsensitiveCompare(city) == .orderedSame }) {
                request.location = match
                await loadDepartmentsAndContacts()
            }
        } catch { directoryError = "De vestigingen konden niet worden geladen. Probeer het opnieuw." }
    }

    private func loadDepartmentsAndContacts() async {
        guard let organization = request.organization, let location = request.location else { return }
        if organization.kind == "school" {
            do {
                departments = try await vault.validationDepartments(organizationID: organization.id, locationID: location.id)
                if departments.isEmpty { request.department = nil }
                await loadContacts()
            } catch { directoryError = "De afdelingen of opleidingen konden niet worden geladen. Probeer het opnieuw." }
        } else { departments = []; request.department = nil; await loadContacts() }
    }

    private func loadContacts() async {
        guard let organization = request.organization, let location = request.location else { return }
        do { contacts = try await vault.validationContacts(organizationID: organization.id, locationID: location.id, departmentID: request.department?.id) }
        catch { directoryError = "De contactpersonen konden niet worden geladen. Probeer het opnieuw." }
    }

    private func select(_ organization: VaultValidationOrganization) async {
        isDirty = true
        directoryError = nil
        request.organization = organization; request.location = nil; request.department = nil; request.contactType = nil; request.contact = nil
        locations = []; departments = []; contacts = []; searchText = ""; choice = nil
        isLoading = true; await loadLocations(); isLoading = false
    }
    private func select(_ location: VaultValidationLocation) async {
        isDirty = true
        directoryError = nil
        request.location = location; request.department = nil; request.contactType = nil; request.contact = nil
        departments = []; contacts = []; searchText = ""; choice = nil
        isLoading = true; await loadDepartmentsAndContacts(); isLoading = false
    }
    private func select(_ department: VaultValidationDepartment) async {
        isDirty = true
        directoryError = nil
        request.department = department; request.contactType = nil; request.contact = nil; contacts = []; searchText = ""; choice = nil
        isLoading = true; await loadContacts(); isLoading = false
    }

    private var evidenceSummary: some View {
        HStack(spacing: 12) {
            VaultLogoAvatar(look: evidenceLogo, name: item.organisationName ?? item.title, size: 56)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(2)
                if let organization = item.organisationName, !organization.isEmpty {
                    let location = item.organisationLocation.map { ", \($0)" } ?? ""
                    PaveIconLabel(icon: .iconBuildingOfficeSolid, text: organization + location)
                }
                if let period = item.period { PaveIconLabel(icon: .iconCalendarDaysSolid, text: period) }
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder) }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill").resizable().scaledToFit().frame(width: 32, height: 32)
                .foregroundStyle(Color.brandGreen).frame(width: 72, height: 72).background(Color.surfaceTint, in: .circle).accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Verzoek verstuurd").textStyle(.emptyTitle).foregroundStyle(Color.ink).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                Text("Je aanvraag is doorgestuurd. Je krijgt een melding zodra het bewijs is beoordeeld.")
                    .textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: 380)
            Spacer(minLength: 0)
            PavePrimaryButton(title: "Sluiten") { dismiss() }.frame(maxWidth: 560)
        }.padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() {
        showsMissing = true
        guard request.missingFields.isEmpty else { PaveHaptics.error(); return }
        guard let onSend, request.organization != nil, request.location != nil, request.contactType != nil, request.contact != nil else { return }
        isSending = true; sendError = nil
        Task {
            let error = await onSend(request)
            isSending = false
            if let error { sendError = error }
            else { isFinished = true }
        }
    }

    private func error(_ field: VaultConfirmationRequest.Field) -> String? {
        guard showsMissing, request.missingFields.contains(field) else { return nil }
        return VaultMessages.requestMissing(field)
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        VaultRequestConfirmationSheet(item: VaultContents.preview.items[0], documentCount: 2)
            .environment(VaultModel(previewContents: VaultContents.preview))
    }
}
