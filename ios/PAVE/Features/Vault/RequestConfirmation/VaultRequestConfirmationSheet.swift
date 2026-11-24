import PAVECore
import SwiftUI

/// "Bevestiging aanvragen": automatic where possible, by hand where needed. The organisation comes from the evidence
/// by its ID; a typed name only suggests one. The learner then picks one person, found by searching the directory on
/// the server, a page at a time, among the persons who may confirm this kind of evidence.
struct VaultRequestConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(VaultModel.self) private var vault
    let item: VaultItem
    let documentCount: Int
    var onShowMenu: (() -> Void)?
    /// Nil sends it through the vault, so every way into this form (the vault, an item, Ayla) really sends.
    var onSend: ((VaultConfirmationRequest) async -> String?)?

    private struct PeopleQuery: Hashable {
        var organizationID: String?
        var search: String
        var filters: VaultValidationFilters
    }

    @State private var request: VaultConfirmationRequest
    @State private var suggestion: VaultValidationOrganization?
    @State private var previousPeople: [VaultValidationPerson] = []
    @State private var people: [VaultValidationPerson] = []
    @State private var peopleTotal = 0
    @State private var filterOptions: [VaultValidationFilterOption] = []
    @State private var isStarting = true
    @State private var isLoadingPeople = false
    @State private var isLoadingMorePeople = false
    @State private var choosesOrganization = false
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
    private var peopleQuery: PeopleQuery { .init(organizationID: request.organization?.id, search: request.search, filters: request.filters) }

    var body: some View {
        NavigationStack {
            Group {
                if isFinished { successView.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing))) }
                else { form.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading))) }
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Kluis", onShowMenu: onShowMenu)
            .toolbarBackground(Color.panel, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
        .animation(.snappy(duration: 0.35), value: isFinished)
        .tint(.paveAccent)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheetDismissGuard(isBlocked: hasChanges) { confirmsDiscard = true }
        .confirmationDialog(VaultMessages.discardRequestTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Weggooien", role: .destructive) { dismiss() }
            Button("Verder met invullen", role: .cancel) {}
        }
        .sheet(isPresented: $choosesOrganization) {
            VaultOrganizationSearchSheet(category: item.category, selectedID: request.organization?.id) { organization in
                if organization.id != request.organization?.id { isDirty = true }
                request.choose(organization)
            }
            .paveSheet()
        }
        .task(id: item.id) {
            evidenceLogo = nil
            if let logo = vault.logo(of: item) { evidenceLogo = await vault.look(of: logo) }
            await start()
        }
        .task(id: request.organization?.id) { await loadFilterOptions() }
        .task(id: peopleQuery) { await loadPeople() }
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Bevestiging aanvragen").textStyle(.calloutTitle).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
                    if let sendError { PaveNotice(message: sendError) }
                    if let directoryError { PaveNotice(message: directoryError) }
                    evidenceSummary
                    organizationSection
                    if request.organization != nil || !previousPeople.isEmpty { contactSection }
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 18)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: request.contact?.id)
            }
            .scrollDismissesKeyboard(.interactively)

            PavePrimaryButton(title: sendTitle) { send() }
                .disabled(isSending || isStarting)
                .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 4).frame(maxWidth: 440)
            if let contact = request.contact {
                Text("Alleen \(contact.name) ziet dit bewijs.")
                    .textStyle(.caption).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center)
                    .frame(maxWidth: 320).padding(.horizontal, 28).padding(.top, 10)
            }
            Spacer().frame(height: 12)
        }
    }

    private var sendTitle: String {
        if isSending { return "Versturen…" }
        if let contact = request.contact { return "Versturen naar \(contact.name)" }
        return "Aanvraag versturen"
    }

    /// What is shared: the evidence, and below it what comes with it.
    private var evidenceSummary: some View {
        HStack(spacing: 12) {
            VaultLogoAvatar(look: evidenceLogo, name: item.organisationName ?? item.title, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(2)
                if let period = item.period { PaveIconLabel(icon: .iconCalendarDaysSolid, text: period) }
                if let shared = sharedLine {
                    Text(shared).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder) }
        .accessibilityElement(children: .combine)
    }

    /// "Met omschrijving, 2 bestanden en 3 vaardigheden".
    private var sharedLine: String? {
        var parts = [String]()
        if let description = item.description, !description.isEmpty { parts.append("omschrijving") }
        if documentCount > 0 { parts.append(VaultMessages.sharedFiles(documentCount)) }
        if !item.skills.isEmpty { parts.append(VaultMessages.sharedSkills(item.skills.count)) }
        guard let last = parts.popLast() else { return nil }
        return "Met " + (parts.isEmpty ? last : parts.joined(separator: ", ") + " en " + last)
    }

    // MARK: Organisation

    private var organizationSection: some View {
        section(title: "Organisatie", error: error(.organisation)) {
            if let organization = request.organization {
                organizationRow(organization) {
                    Button("Wijzig") { choosesOrganization = true }
                        .textStyle(.link).foregroundStyle(Color.paveAccent).buttonStyle(.pave)
                        .accessibilityLabel("Andere organisatie kiezen")
                }
            } else if isStarting {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
            } else {
                if let suggestion {
                    organizationRow(suggestion, prefix: "Bedoel je ") {
                        Button("Kiezen") {
                            isDirty = true
                            request.choose(suggestion)
                        }
                        .textStyle(.link).foregroundStyle(Color.paveAccent).buttonStyle(.pave)
                        .accessibilityLabel("\(suggestion.name) kiezen")
                    }
                }
                searchButton(suggestion == nil ? "Zoek een organisatie" : "Andere organisatie zoeken") { choosesOrganization = true }
            }
        }
    }

    private func organizationRow<Action: View>(
        _ organization: VaultValidationOrganization, prefix: String = "", @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: 12) {
            Image(organization.organizationKind.icon)
                .renderingMode(.template).resizable().scaledToFit().paveIconFrame(18)
                .foregroundStyle(Color.paveAccent)
                .paveIconFrame(40)
                .background(Color.paveDropZone, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(prefix.isEmpty ? organization.name : "\(prefix)\(organization.name)?")
                    .textStyle(.label).foregroundStyle(Color.ink).lineLimit(2)
                Text([organization.kindTitle, organization.citySummary].compactMap { $0 }.joined(separator: " · "))
                    .textStyle(.caption).foregroundStyle(Color.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 8)
            action()
        }
    }

    // MARK: Contact person

    private var contactSection: some View {
        section(title: "Contactpersoon", error: error(.contact)) {
            if request.organization == nil {
                subheading("Eerder benaderd")
                ForEach(previousPeople) { person in
                    personRow(person, details: [person.details, person.organizationName].compactMap { $0 }.joined(separator: " · "))
                }
            } else if request.organization?.availableContacts == 0 {
                Text("Hier kan niemand dit soort bewijs bevestigen.")
                    .textStyle(.caption).foregroundStyle(Color.inkMuted)
            } else {
                PaveSearchField(text: $request.search, prompt: "Zoek op naam, functie of plaats")
                filterBar
                peopleList
            }
        }
    }

    @ViewBuilder
    private var peopleList: some View {
        let isBrowsing = request.search.isEmpty && request.filters.isEmpty
        let previousHere = isBrowsing ? previousPeople.filter { $0.organizationId == request.organization?.id } : []
        let rest = people.filter { person in !previousHere.contains { $0.id == person.id } }
        if !previousHere.isEmpty {
            subheading("Eerder benaderd")
            ForEach(previousHere) { person in personRow(person) }
            if !rest.isEmpty { subheading("Alle contactpersonen") }
        }
        if isLoadingPeople && people.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 10)
        } else if people.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Niemand gevonden.").textStyle(.label).foregroundStyle(Color.ink)
                if !request.filters.isEmpty {
                    Button("Filters wissen") { request.filters = .init() }
                        .textStyle(.link).foregroundStyle(Color.paveAccent).buttonStyle(.pave)
                }
            }
            .padding(.vertical, 4)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(rest) { person in personRow(person) }
            }
            .opacity(isLoadingPeople ? 0.5 : 1)
            if people.count < peopleTotal {
                Button {
                    Task { await loadMorePeople() }
                } label: {
                    Text(isLoadingMorePeople ? "Laden…" : "Meer laden (\(people.count) van \(peopleTotal))")
                        .textStyle(.link).foregroundStyle(Color.paveAccent).frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(.pave).disabled(isLoadingMorePeople)
            }
        }
    }

    /// Only filters that narrow something: one location means no location filter.
    @ViewBuilder
    private var filterBar: some View {
        let locations = filterOptions.filter { $0.filter == .location }
        let departments = filterOptions.filter {
            $0.filter == .department && (request.filters.locationID == nil || $0.locationId == request.filters.locationID)
        }
        let functions = filterOptions.filter { $0.filter == .function }
        if locations.count > 1 || departments.count > 1 || functions.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if locations.count > 1 {
                        filterMenu("Vestiging", all: "Alle vestigingen", options: locations, value: request.filters.locationID) { value in
                            request.filters.locationID = value
                            if value != nil, let department = request.filters.departmentID,
                               !filterOptions.contains(where: { $0.filter == .department && $0.value == department && $0.locationId == value }) {
                                request.filters.departmentID = nil
                            }
                        }
                    }
                    if departments.count > 1 {
                        filterMenu("Afdeling", all: "Alle afdelingen", options: departments, value: request.filters.departmentID) {
                            request.filters.departmentID = $0
                        }
                    }
                    if functions.count > 1 {
                        filterMenu("Functie", all: "Alle functies", options: functions, value: request.filters.function) {
                            request.filters.function = $0
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func filterMenu(
        _ title: String, all: String, options: [VaultValidationFilterOption], value: String?, select: @escaping (String?) -> Void
    ) -> some View {
        let label = options.first { $0.value == value }?.label
        return Menu {
            Picker(title, selection: Binding(get: { value }, set: { select($0) })) {
                Text(all).tag(String?.none)
                ForEach(options) { option in Text(option.label).tag(Optional(option.value)) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(label ?? title).textStyle(.caption).lineLimit(1)
                Image(.iconChevronDown).resizable().scaledToFit().frame(width: 10, height: 10)
            }
            .foregroundStyle(label == nil ? Color.ink : Color.paveAccent)
            .padding(.horizontal, 12).frame(height: 32)
            .background(label == nil ? Color.panel : Color.paveDropZone, in: .capsule)
            .overlay { Capsule().strokeBorder(label == nil ? Color.cardBorder : Color.paveFocusRing) }
        }
        .accessibilityLabel("\(title): \(label ?? "alle")")
    }

    /// Name, then function, department and location, so two people with the same name differ.
    private func personRow(_ person: VaultValidationPerson, details: String? = nil) -> some View {
        let isSelected = request.contact?.id == person.id
        return Button {
            PaveHaptics.selection()
            choose(person)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.name).textStyle(.label).foregroundStyle(Color.ink)
                    Text(details ?? person.details)
                        .textStyle(.caption).foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Circle()
                    .strokeBorder(isSelected ? Color.paveAccent : .railBorder, lineWidth: isSelected ? 6 : 1.5)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(isSelected ? Color.paveDropZone : Color.panel, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? Color.paveFocusRing : .railBorder) }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// An earlier contact of another organisation brings that organisation along.
    private func choose(_ person: VaultValidationPerson) {
        isDirty = true
        if person.organizationId != request.organization?.id {
            request.choose(VaultValidationOrganization(
                id: person.organizationId, name: person.organizationName ?? "", kind: "other", cities: [person.city]
            ))
            Task { await refreshOrganization(person.organizationId) }
        }
        request.contact = person
    }

    // MARK: Building blocks

    private func section<Content: View>(title: String, error: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).textStyle(.label).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
            content()
            if let error { PaveInlineError(message: error) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
    }

    private func subheading(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.eyebrow).foregroundStyle(Color.inkMuted).padding(.top, 2)
    }

    private func searchButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(.iconSearch).renderingMode(.template).foregroundStyle(Color.inkMuted).accessibilityHidden(true)
                Text(title).textStyle(.input).foregroundStyle(Color.inkMuted).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).frame(height: 48)
            .background(Color.panel, in: .rect(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.cardBorder) }
            .contentShape(.rect(cornerRadius: 11))
        }
        .buttonStyle(.pave)
    }

    // MARK: - Loading

    /// The organisation by ID when the evidence or an earlier request names one; otherwise a suggestion from the typed
    /// name. And who the learner asked before.
    private func start() async {
        isStarting = true; defer { isStarting = false }
        async let previous = try? vault.previousValidationPeople(category: item.category)
        let known = VaultConfirmationRequest.knownOrganizationIDs(for: item)
        do {
            if !known.isEmpty {
                let found = try await vault.validationOrganizations(ids: known.map(\.id), category: item.category)
                // The first known organisation where someone may confirm it, otherwise simply the first known one.
                let ranked = known.compactMap { entry in found.first { $0.id == entry.id }.map { ($0, entry.source) } }
                if request.organization == nil,
                   let (organization, source) = ranked.first(where: { ($0.0.availableContacts ?? 0) > 0 }) ?? ranked.first {
                    request.choose(organization, source: source)
                }
            }
            if request.organization == nil, let name = item.organisationName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                let page = try await vault.searchValidationOrganizations(category: item.category, query: name, kind: nil, offset: 0)
                suggestion = VaultConfirmationRequest.suggestion(for: item, among: page.rows)
            }
        } catch {
            directoryError = "De organisaties konden niet worden geladen. Probeer het opnieuw."
        }
        previousPeople = await previous ?? []
    }

    /// Fills in kind and cities of an organisation that came along with an earlier contact.
    private func refreshOrganization(_ id: String) async {
        guard let found = try? await vault.validationOrganizations(ids: [id], category: item.category).first,
              request.organization?.id == id else { return }
        request.organization = found
    }

    private func loadFilterOptions() async {
        filterOptions = []
        guard let organization = request.organization else { return }
        filterOptions = (try? await vault.validationFilterOptions(organizationID: organization.id, category: item.category)) ?? []
    }

    /// The first page for the current search; typing waits a moment so not every letter goes to the server.
    private func loadPeople() async {
        let query = peopleQuery
        guard let organizationID = query.organizationID else { people = []; peopleTotal = 0; return }
        // Another organisation: its people only, not those of the one before.
        if people.first.map({ $0.organizationId != organizationID }) == true { people = []; peopleTotal = 0 }
        if !people.isEmpty || !query.search.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
        guard !Task.isCancelled else { return }
        isLoadingPeople = true; defer { isLoadingPeople = false }
        do {
            let page = try await vault.searchValidationPeople(
                organizationID: organizationID, category: item.category, query: query.search, filters: query.filters, offset: 0
            )
            guard !Task.isCancelled, query == peopleQuery else { return }
            people = page.rows
            peopleTotal = page.total
            directoryError = nil
        } catch {
            guard !Task.isCancelled else { return }
            directoryError = "De contactpersonen konden niet worden geladen. Probeer het opnieuw."
        }
    }

    private func loadMorePeople() async {
        let query = peopleQuery
        guard let organizationID = query.organizationID, !isLoadingMorePeople else { return }
        isLoadingMorePeople = true; defer { isLoadingMorePeople = false }
        guard let page = try? await vault.searchValidationPeople(
            organizationID: organizationID, category: item.category, query: query.search, filters: query.filters, offset: people.count
        ), query == peopleQuery else { return }
        people += page.rows.filter { row in !people.contains { $0.id == row.id } }
        peopleTotal = page.total
    }

    // MARK: - Result

    private var successView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill").resizable().scaledToFit().frame(width: 32, height: 32)
                .foregroundStyle(Color.paveAccent).frame(width: 72, height: 72).background(Color.paveSurfaceTint, in: .circle).accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Verzoek verstuurd").textStyle(.emptyTitle).foregroundStyle(Color.ink).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                Text("Je krijgt een melding zodra \(request.contact?.name ?? "de contactpersoon") het heeft beoordeeld.")
                    .textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: 380)
            Spacer(minLength: 0)
            PavePrimaryButton(title: "Sluiten") { dismiss() }.frame(maxWidth: 560)
        }.padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() {
        showsMissing = true
        guard request.missingFields.isEmpty else { PaveHaptics.error(); return }
        isSending = true; sendError = nil
        Task {
            let error: String? = if let onSend {
                await onSend(request)
            } else {
                await vault.requestValidation(for: item, request)
            }
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

extension VaultOrganizationKind {
    var icon: ImageResource {
        switch self {
        case .school: .iconAcademicCapSolid
        case .company: .iconBuildingOfficeSolid
        case .government: .iconShieldCheckSolid
        case .other: .iconUserGroupSolid
        }
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        VaultRequestConfirmationSheet(item: VaultContents.preview.items[0], documentCount: 2)
            .environment(VaultModel(previewContents: VaultContents.preview))
    }
}
