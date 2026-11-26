import PAVECore
import SwiftUI

/// "Bevestiging aanvragen": automatic where possible, by hand where needed. The learner chooses an organisation with
/// one of its locations ("Albert Heijn · Breda"), known by ID from an earlier request where possible; a typed name only
/// suggests one. Then one person there, found by searching the directory on the server, a page at a time, among the
/// persons who may confirm this kind of evidence.
struct VaultRequestConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(VaultModel.self) private var vault
    @Environment(\.openDestination) private var openDestination
    let item: VaultItem
    let documentCount: Int
    /// Nil sends it through the vault, so every way into this form (the vault, an item, Ayla) really sends.
    var onSend: ((VaultConfirmationRequest) async -> String?)?

    private struct PeopleQuery: Hashable {
        var place: VaultValidationPlace?
        var search: String
        var filters: VaultValidationFilters
    }

    @State private var request: VaultConfirmationRequest
    @State private var suggestion: VaultValidationPlace?
    /// What the place search starts with: the organisation of the evidence, when its location is not certain.
    @State private var suggestedSearch = ""
    @State private var previousPeople: [VaultValidationPerson] = []
    @State private var people: [VaultValidationPerson] = []
    @State private var peopleTotal = 0
    @State private var filterOptions: [VaultValidationFilterOption] = []
    /// Profile photos by contact person, fetched for the persons on screen.
    @State private var photos: [String: URL] = [:]
    @State private var photosAsked: Set<String> = []
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

    init(item: VaultItem, documentCount: Int, onSend: ((VaultConfirmationRequest) async -> String?)? = nil) {
        self.item = item
        self.documentCount = documentCount
        self.onSend = onSend
        _request = State(initialValue: VaultConfirmationRequest(item: item))
    }

    private var hasChanges: Bool { !isFinished && isDirty }
    private var peopleQuery: PeopleQuery { .init(place: request.place, search: request.search, filters: request.filters) }

    var body: some View {
        NavigationStack {
            Group {
                if isFinished { successView.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing))) }
                else { form.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading))) }
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFinished {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(VaultMessages.cancel) {
                            if hasChanges { confirmsDiscard = true } else { dismiss() }
                        }
                    }
                }
            }
            .toolbarBackground(Color.panel, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
        .animation(.snappy(duration: 0.35), value: isFinished)
        .tint(.paveAccent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheetDismissGuard(isBlocked: hasChanges) { confirmsDiscard = true }
        .confirmationDialog(VaultMessages.discardRequestTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Weggooien", role: .destructive) { dismiss() }
            Button("Verder met invullen", role: .cancel) {}
        }
        .sheet(isPresented: $choosesOrganization) {
            VaultOrganizationSearchSheet(
                category: item.category, selectedID: request.place?.locationId,
                initialQuery: request.place == nil ? suggestedSearch : ""
            ) { place in
                if place.locationId != request.place?.locationId { isDirty = true }
                request.choose(place)
            }
            .paveSheet()
        }
        .task(id: item.id) {
            evidenceLogo = nil
            if let logo = vault.logo(of: item) { evidenceLogo = await vault.look(of: logo) }
            await start()
        }
        .task(id: request.place?.organizationId) { await loadFilterOptions() }
        .task(id: peopleQuery) { await loadPeople() }
        .task(id: (people + previousPeople).map(\.id)) { await loadPhotos() }
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
                    if request.place != nil || !previousPeople.isEmpty { contactSection }
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
            if let place = request.place {
                placeRow(place) {
                    Button("Wijzig") { choosesOrganization = true }
                        .textStyle(.link).foregroundStyle(Color.paveAccent).buttonStyle(.pave)
                        .accessibilityLabel("Andere organisatie of vestiging kiezen")
                }
            } else if isStarting {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
            } else {
                if let suggestion {
                    placeRow(suggestion, asks: true) {
                        Button("Kiezen") {
                            isDirty = true
                            request.choose(suggestion)
                        }
                        .textStyle(.link).foregroundStyle(Color.paveAccent).buttonStyle(.pave)
                        .accessibilityLabel("\(suggestion.title) kiezen")
                    }
                }
                searchButton(searchTitle) { choosesOrganization = true }
            }
        }
    }

    private var searchTitle: String {
        if suggestion != nil { return "Andere zoeken" }
        if !suggestedSearch.isEmpty { return "Kies een vestiging van \(suggestedSearch)" }
        return "Zoek een organisatie of plaats"
    }

    /// "Albert Heijn" with "Bedrijf · Breda" under it, or "Bedrijf · Westermarkt, Tilburg" and the address.
    private func placeRow<Action: View>(
        _ place: VaultValidationPlace, asks: Bool = false, @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: 12) {
            VaultPlaceLogo(place: place, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(asks ? "Bedoel je \(place.organizationName)?" : place.organizationName)
                    .textStyle(.label).foregroundStyle(Color.ink).lineLimit(2)
                Text("\(place.organizationKind.title) · \(place.locationTitle)")
                    .textStyle(.caption).foregroundStyle(Color.inkMuted).lineLimit(2)
                if let address = place.addressLine {
                    Text(address).textStyle(.caption).foregroundStyle(Color.inkMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            action()
        }
    }

    // MARK: Contact person

    private var contactSection: some View {
        section(title: "Contactpersoon", error: error(.contact)) {
            if request.place == nil {
                subheading("Eerder benaderd")
                ForEach(previousPeople) { person in
                    personRow(person, details: [person.details, person.organizationName].compactMap { $0 }.joined(separator: " · "))
                }
            } else if request.place?.availableContacts == 0 {
                Text("Bij deze vestiging kan niemand dit soort bewijs bevestigen.")
                    .textStyle(.caption).foregroundStyle(Color.inkMuted)
            } else {
                PaveSearchField(text: $request.search, prompt: "Zoek op naam of functie")
                filterBar
                peopleList
            }
        }
    }

    @ViewBuilder
    private var peopleList: some View {
        let isBrowsing = request.search.isEmpty && request.filters.isEmpty
        let previousHere = isBrowsing ? previousPeople.filter { $0.locationId == request.place?.locationId } : []
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

    /// Only filters that narrow something at this location. The location itself is chosen, not filtered.
    @ViewBuilder
    private var filterBar: some View {
        let departments = options(.department, at: request.place?.locationId)
        let functions = options(.function, at: request.place?.locationId)
        if departments.count > 1 || functions.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if departments.count > 1 {
                        filterMenu("Afdeling", all: "Alle afdelingen", options: departments, value: request.filters.department) {
                            request.filters.department = $0
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

    /// The departments or functions at one location, each name once. Before migration 20261124150000 functions come
    /// without a location: then all of them.
    private func options(_ filter: VaultValidationFilterOption.Filter, at locationID: String?) -> [VaultValidationFilterOption] {
        let shown = filterOptions.filter { $0.filter == filter && ($0.locationId == nil || locationID == nil || $0.locationId == locationID) }
        return Dictionary(grouping: shown, by: \.label)
            .map { name, options in
                VaultValidationFilterOption(filter: filter, value: name, label: name, people: options.reduce(0) { $0 + $1.people })
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
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
                VaultPersonPhoto(name: person.name, url: photos[person.id])
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

    /// An earlier contact elsewhere brings their organisation and location along.
    private func choose(_ person: VaultValidationPerson) {
        isDirty = true
        if person.locationId != request.place?.locationId {
            request.choose(VaultValidationPlace(
                organizationId: person.organizationId, organizationName: person.organizationName ?? "",
                kind: "other", locationId: person.locationId, city: person.city, locationName: person.locationName
            ))
            Task { await refreshPlace(person.locationId) }
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

    /// The organisation by ID, at the location in the city the evidence names (the location field, or else the
    /// description). The location of an earlier request only
    /// when the evidence names no city, or one where the organisation has no location: what the learner wrote with
    /// the evidence wins. Otherwise a suggestion from the typed name. And who the learner asked before.
    private func start() async {
        isStarting = true; defer { isStarting = false }
        async let previous = try? vault.previousValidationPeople(category: item.category)
        do {
            var earlier: VaultValidationPlace?
            if let locationID = VaultConfirmationRequest.knownLocationID(for: item) {
                earlier = try await vault.validationPlaces(locationIDs: [locationID], category: item.category).first
            }
            if let earlier, VaultConfirmationRequest.fitsTypedCity(earlier, of: item) {
                request.choose(earlier, source: .earlierRequest)
            }
            for known in VaultConfirmationRequest.knownOrganizationIDs(for: item) where request.place == nil {
                let places = try await vault.searchValidationPlaces(
                    category: item.category, query: "", kind: nil, organizationID: known.id, offset: 0
                ).rows
                if let place = VaultConfirmationRequest.onlyPlace(
                    places, typedCity: item.organisationLocation, described: item.description
                ) {
                    request.choose(place, source: known.source)
                } else if let first = places.first, suggestedSearch.isEmpty {
                    // Two locations in the typed city: the search lists just those.
                    suggestedSearch = VaultConfirmationRequest.searchHint(places, for: item) ?? first.organizationName
                }
            }
            // The typed city is not one of its locations: then the earlier request after all.
            if request.place == nil, let earlier { request.choose(earlier, source: .earlierRequest) }
            if request.place == nil, suggestedSearch.isEmpty, let name = item.organisationName,
               !name.trimmingCharacters(in: .whitespaces).isEmpty {
                let places = try await vault.searchValidationPlaces(
                    category: item.category, query: name, kind: nil, offset: 0
                ).rows
                suggestion = VaultConfirmationRequest.suggestion(for: item, among: places)
                if suggestion == nil {
                    let named = places.filter { VaultConfirmationRequest.normalised($0.organizationName) == VaultConfirmationRequest.normalised(name) }
                    suggestedSearch = VaultConfirmationRequest.searchHint(named, for: item) ?? ""
                }
            }
        } catch {
            directoryError = "De organisaties konden niet worden geladen. Probeer het opnieuw."
        }
        previousPeople = await previous ?? []
    }

    /// Fills in the kind of a location that came along with an earlier contact.
    private func refreshPlace(_ locationID: String) async {
        guard let found = try? await vault.validationPlaces(locationIDs: [locationID], category: item.category).first,
              request.place?.locationId == locationID else { return }
        request.place = found
    }

    private func loadFilterOptions() async {
        filterOptions = []
        guard let place = request.place else { return }
        filterOptions = (try? await vault.validationFilterOptions(organizationID: place.organizationId, category: item.category)) ?? []
    }

    /// The first page for the current search; typing waits a moment so not every letter goes to the server.
    private func loadPeople() async {
        let query = peopleQuery
        guard let place = query.place else { people = []; peopleTotal = 0; return }
        // Another location: its people only, not those of the one before.
        if people.first.map({ $0.locationId != place.locationId }) == true { people = []; peopleTotal = 0 }
        if !people.isEmpty || !query.search.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
        guard !Task.isCancelled else { return }
        isLoadingPeople = true; defer { isLoadingPeople = false }
        do {
            let page = try await vault.searchValidationPeople(
                organizationID: place.organizationId, category: item.category, query: query.search,
                filters: Self.filters(query.filters, at: place), offset: 0
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
        guard let place = query.place, !isLoadingMorePeople else { return }
        isLoadingMorePeople = true; defer { isLoadingMorePeople = false }
        guard let page = try? await vault.searchValidationPeople(
            organizationID: place.organizationId, category: item.category, query: query.search,
            filters: Self.filters(query.filters, at: place), offset: people.count
        ), query == peopleQuery else { return }
        people += page.rows.filter { row in !people.contains { $0.id == row.id } }
        peopleTotal = page.total
    }

    /// The photos of the persons on screen that were not asked for yet. Only an answered request counts as asked: when
    /// the list changes halfway (the earlier contacts arrive after the first people), this task is cancelled and the
    /// next one asks for these persons again.
    private func loadPhotos() async {
        let missing = (people + previousPeople).map(\.id).filter { !photosAsked.contains($0) }
        guard !missing.isEmpty else { return }
        let found = await vault.validationContactPhotos(contactIDs: missing)
        photos.merge(found) { _, new in new }
        guard !Task.isCancelled else { return }
        photosAsked.formUnion(missing)
    }

    /// The chosen filters, always at the chosen location.
    private static func filters(_ filters: VaultValidationFilters, at place: VaultValidationPlace) -> VaultValidationFilters {
        var filters = filters
        filters.locationID = place.locationId
        return filters
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
            VStack(spacing: 10) {
                if let openDestination {
                    PavePrimaryButton(title: VaultMessages.seeInNotifications) {
                        dismiss()
                        openDestination(.notifications)
                    }
                    PaveSecondaryButton(title: "Sluiten") { dismiss() }
                } else {
                    PavePrimaryButton(title: "Sluiten") { dismiss() }
                }
            }
            .frame(maxWidth: 560)
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

/// The organisation's logo: its `logo_url`, otherwise the logo PAVE finds on its own site (only the public name goes
/// out), otherwise an icon. Loaded once while the app runs.
struct VaultPlaceLogo: View {
    let place: VaultValidationPlace
    var size: CGFloat = 40

    var body: some View {
        // One logo for the whole organisation: looked up by name only, so every location shows the same one.
        CompanyLogo(name: place.organizationName, url: place.logoURL, size: size, fills: true)
            .id(place.organizationId)
    }
}

/// A contact person's profile photo, or their initials.
struct VaultPersonPhoto: View {
    let name: String
    let url: URL?
    var size: CGFloat = 36

    private var initials: String {
        name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased()
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Text(initials).textStyle(.caption).foregroundStyle(Color.paveAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.paveDropZone)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        VaultRequestConfirmationSheet(item: VaultContents.preview.items[0], documentCount: 2)
            .environment(VaultModel(previewContents: VaultContents.preview))
    }
}
