import PAVECore
import SwiftUI
import UserNotifications

enum NotificationAudience: Equatable, Sendable {
    case learner
    case administrator
}

enum PaveNotificationKind: String, CaseIterable, Hashable, Identifiable, Sendable {
    case conversation
    case verifiedEvidence
    case rejectedEvidence
    case verificationRequest

    var id: Self { self }

    var title: String {
        switch self {
        case .conversation: "Gesprek"
        case .verifiedEvidence: "Verificatie"
        case .rejectedEvidence: "Afgewezen bewijs"
        case .verificationRequest: "Verificatie aanvraag"
        }
    }

    var filterTitle: String {
        self == .verificationRequest ? "Verificatie" : title
    }

    var description: String {
        switch self {
        case .conversation: "Berichten en antwoorden over gesprekken"
        case .verifiedEvidence: "Bewijs dat is geverifieerd"
        case .rejectedEvidence: "Bewijs dat is afgewezen"
        case .verificationRequest: "Aanvragen die je kunt beoordelen"
        }
    }

    var icon: ImageResource {
        switch self {
        case .conversation: .iconChat
        case .verifiedEvidence: .iconCheckBadgeSolid
        case .rejectedEvidence: .iconExclamationCircle
        case .verificationRequest: .iconDocumentTextSolid
        }
    }

    /// The icon's colour: red for rejected, amber for a request waiting on you, otherwise the app's green.
    var tint: Color {
        switch self {
        case .rejectedEvidence: .statusRejected
        case .verificationRequest: .statusPending
        case .conversation, .verifiedEvidence: .paveAccent
        }
    }

    /// The tile behind the icon, in the same family as `tint`.
    var surface: Color {
        switch self {
        case .rejectedEvidence: .statusRejectedSurface
        case .verificationRequest: .statusPendingSurface
        case .conversation, .verifiedEvidence: .paveSurfaceTint
        }
    }
}

struct PaveNotification: Identifiable, Hashable, Sendable {
    let id: String
    let kind: PaveNotificationKind
    let title: String
    let personName: String
    let date: Date
    var isUnread = true
    /// Set when you delete it: it then sits in "Recent verwijderd" until `restoreDeadline`.
    var deletedAt: Date?
    var conversationID: String?
    var validationRequestID: String? = nil
    var vaultItemID: String?
    var learnerName: String?
    var learnerOrganization: String?
    var documentName: String?
    var documentType: String?
    var documentFileName: String?
}

extension PaveNotification {
    /// Who or what it is about, for the line under the title in the list and the banner.
    var detail: String {
        switch kind {
        case .verifiedEvidence, .rejectedEvidence:
            [documentName, personName].compactMap { $0 }.joined(separator: " · ")
        case .verificationRequest:
            [learnerName ?? personName, documentName].compactMap { $0 }.joined(separator: " · ")
        case .conversation:
            personName
        }
    }

    /// How long a deleted notification can be brought back; the server purges it after that (`vault-review`, pg_cron).
    static let restorableDays = 7

    var restoreDeadline: Date? {
        deletedAt.flatMap { Calendar.current.date(byAdding: .day, value: Self.restorableDays, to: $0) }
    }
}

extension View {
    /// A list row without the list's own background, separator and full-width insets, so the inbox keeps its cards.
    func notificationListRow(top: CGFloat = 8, bottom: CGFloat = 8) -> some View {
        frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

struct NotificationsScreen: View {
    let onShowMenu: (() -> Void)?
    var audience: NotificationAudience = .learner
    var notifications: [PaveNotification] = []
    var loadError: String?
    var onRefresh: (() async -> Void)?
    var onMarkRead: ((String) async -> Void)?
    var onMarkAllRead: (() async -> Void)?
    var onOpenConversation: ((String) -> Void)?
    var onOpenVerifiedEvidence: ((String) -> Void)?
    var onLoadReview: ((String) async -> (payload: NotificationReviewPayload?, error: String?))?
    var onResolveRequest: ((String, String, String?) async -> String?)?
    /// Both report whether the server saved it; the model puts the notification back if not.
    var onDelete: ((String) async -> Bool)?
    var onRestore: ((String) async -> Bool)?
    /// Applications with the demo's invitation from the company, kept on this device; they open Mijn sollicitatie.
    var invitations: [ApplicationDraft] = []
    var onOpenApplication: ((Vacancy) -> Void)?

    @State private var searchText = ""
    @State private var alertStatus: UNAuthorizationStatus?
    @Environment(\.openURL) private var openURL
    @State private var showsTrash = false
    @State private var openedNotification: PaveNotification?
    @State private var readIDs: Set<String> = []
    /// The meldingen just deleted (a chat with several is one row), while "Ongedaan maken" is on screen.
    @State private var undoIDs: [String] = []
    /// What was just done with a verification request, shown for a moment after coming back to the list.
    @State private var resolved: String?

    /// Search only earns its place once the list is long enough to need it.
    private static let searchThreshold = 8

    /// Everything not deleted.
    private var inbox: [PaveNotification] {
        notifications.filter { $0.deletedAt == nil }
    }

    /// "Recent verwijderd": newest deletion first.
    private var deletedNotifications: [PaveNotification] {
        notifications
            .filter { ($0.restoreDeadline ?? .distantPast) > .now }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    private var visibleNotifications: [PaveNotification] {
        inbox
            .filter {
                searchText.isEmpty || [
                    $0.title, $0.personName, $0.documentName ?? "", $0.documentType ?? ""
                ].joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.date > $1.date }
            .reduce(into: ([PaveNotification](), Set<String>())) { result, item in
                // Ayla's meldingen of one chat are one row, the newest on top.
                if item.kind == .conversation, let chat = item.conversationID {
                    guard result.1.insert(chat).inserted else { return }
                }
                result.0.append(item)
            }
            .0
    }

    private var hasUnread: Bool {
        inbox.contains { $0.isUnread && !readIDs.contains($0.id) }
    }

    /// Everything behind one row: all meldingen of the same chat, or just the one.
    private func ids(of notification: PaveNotification) -> [String] {
        guard notification.kind == .conversation, let chat = notification.conversationID else { return [notification.id] }
        return inbox.filter { $0.kind == .conversation && $0.conversationID == chat }.map(\.id)
    }

    var body: some View {
        NavigationStack {
            // A List, not a ScrollView, because only a List has swipe actions.
            List {
                Group {
                if let loadError {
                    Text(loadError)
                        .textStyle(.caption)
                        .foregroundStyle(Color.statusRejected)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.panel, in: .rect(cornerRadius: 12))
                }
                if alertStatus == .notDetermined || alertStatus == .denied {
                    alertsCard
                }
                if inbox.count >= Self.searchThreshold || !searchText.isEmpty {
                    PaveSearchField(text: $searchText, prompt: "Zoek in meldingen")
                }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                if !invitations.isEmpty, searchText.isEmpty {
                    Section {
                        ForEach(invitations) { draft in
                            if let invitation = draft.progress.invitation {
                                Button { onOpenApplication?(draft.vacancy) } label: {
                                    NotificationInvitationRow(draft: draft, invitation: invitation)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.panel)
                                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                            }
                        }
                    } header: {
                        Text(ApplyMessages.fromEmployers)
                            .textStyle(.caption)
                            .foregroundStyle(Color.paveAccent)
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                notificationList
            }
            // One grouped list, like Instellingen: a panel per section with dividers, not a card per melding.
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
            .animation(.snappy, value: visibleNotifications.map(\.id))
            .refreshable { await onRefresh?() }
            .safeAreaInset(edge: .bottom, spacing: 12) {
                if !undoIDs.isEmpty {
                    AylaUndoBar(message: "Melding verwijderd") { undoDelete() }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: 560)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let resolved {
                    NotificationResolvedBar(message: resolved)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: 560)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: undoIDs)
            .animation(.snappy, value: resolved)
            .task(id: resolved) {
                guard resolved != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                resolved = nil
            }
            .task(id: undoIDs) {
                guard !undoIDs.isEmpty else { return }
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                undoIDs = []
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Meldingen", onShowMenu: onShowMenu)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { moreMenu }
            }
            .navigationDestination(isPresented: Binding(
                get: { openedNotification != nil },
                set: { if !$0 { openedNotification = nil } }
            )) {
                if let notification = openedNotification {
                    if notification.kind == .verificationRequest {
                        VerificationRequestNotificationDetail(
                            notification: notification,
                            onLoadReview: onLoadReview,
                            onResolve: onResolveRequest.map { resolve in
                                { id, status, reason in
                                    let error = await resolve(id, status, reason)
                                    if error == nil {
                                        resolved = status == "verified" ? NotificationResolvedBar.verified : NotificationResolvedBar.rejected
                                    }
                                    return error
                                }
                            }
                        )
                    } else {
                        NotificationMessageDetail(notification: notification)
                    }
                }
            }
            .navigationDestination(isPresented: $showsTrash) {
                NotificationTrashScreen(notifications: deletedNotifications, onRestore: onRestore)
            }
        }
        .tint(.paveAccent)
        .task { await onRefresh?() }
        .task { alertStatus = await NotificationAlerts.status() }
    }

    /// Asked here, by choice, and not at launch: the first time iOS shows its question is when you tap "Zet aan".
    private var alertsCard: some View {
        let denied = alertStatus == .denied
        return HStack(spacing: 11) {
            Image(.iconBellSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.paveAccent)
                .frame(width: 18, height: 18)
                .frame(width: 36, height: 36)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(denied ? "Meldingen staan uit in iOS" : "Een seintje bij nieuwe meldingen?")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                Text(denied ? "Zet ze aan in de Instellingen van je iPhone." : "Je ziet het ook als PAVE dicht is. Alleen de titel, nooit je bewijs.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 6)
            Button(denied ? "Instellingen" : "Zet aan") {
                if denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    Task {
                        _ = await NotificationAlerts.requestPermission()
                        alertStatus = await NotificationAlerts.status()
                    }
                }
            }
            .textStyle(.caption)
            .foregroundStyle(Color.paveAccent)
            .buttonStyle(.pave)
        }
        .padding(10)
        .background(Color.panel, in: .rect(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Color.cardBorder) }
    }

    /// Everything that is not about one melding: read them all, and the bin.
    private var moreMenu: some View {
        Menu {
            Button {
                markAllRead()
            } label: {
                Label("Alles als gelezen markeren", image: .iconMailOpen)
            }
            .disabled(!hasUnread)
            Button { showsTrash = true } label: {
                Label(
                    deletedNotifications.isEmpty ? "Recent verwijderd" : "Recent verwijderd (\(deletedNotifications.count))",
                    image: .iconTrash
                )
            }
        } label: {
            Image(.iconEllipsis)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.ink)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Meer")
    }

    @ViewBuilder
    private var notificationList: some View {
        if visibleNotifications.isEmpty {
            if searchText.isEmpty {
                PaveEmptyState(
                    icon: .iconMailOpen,
                    title: "Je bent helemaal bij",
                    message: emptyMessage
                )
                .padding(.top, 30)
                .frame(maxWidth: .infinity)
                .notificationListRow()
            } else {
                PaveEmptyState(
                    icon: .iconSearch,
                    title: "Niets gevonden",
                    message: "Probeer een andere zoekterm."
                )
                .padding(.top, 30)
                .frame(maxWidth: .infinity)
                .notificationListRow()
            }
        } else {
            ForEach(groupedNotifications, id: \.title) { section in
                Section {
                    ForEach(section.items) { notification in
                        row(notification)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(section.title)
                            .textStyle(.caption)
                            .foregroundStyle(section.needsAction ? Color.paveAccent : Color.inkMuted)
                        if section.needsAction {
                            Text("\(section.items.count)")
                                .textStyle(.caption)
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 7)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(Color.paveAccentFill, in: .capsule)
                        }
                    }
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
    }

    private var emptyMessage: String {
        switch audience {
        case .learner: "Zodra een organisatie je bewijs beoordeelt, zie je dat hier."
        case .administrator: "Nieuwe verificatieaanvragen en beslissingen verschijnen hier."
        }
    }

    /// Opens the notification; swipe left or hold it to delete.
    private func row(_ notification: PaveNotification) -> some View {
        Button { open(notification) } label: {
            NotificationInboxRow(notification: notification, isUnread: isUnread(notification), count: ids(of: notification).count)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.panel)
        .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(notification) } label: {
                Label("Verwijderen", image: .iconTrash)
            }
            // Red, not the app's green tint.
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if isUnread(notification) {
                Button { markRead(notification) } label: {
                    Label("Gelezen", image: .iconMailOpen)
                }
                .tint(.paveAccent)
            }
        }
        .contextMenu { menu(for: notification) }
        .accessibilityElement(children: .combine)
        .accessibilityActions { menu(for: notification) }
    }

    @ViewBuilder
    private func menu(for notification: PaveNotification) -> some View {
        if isUnread(notification) {
            Button { markRead(notification) } label: {
                Label("Markeer als gelezen", image: .iconMailOpen)
            }
        }
        Button(role: .destructive) { delete(notification) } label: {
            Label("Verwijderen", image: .iconTrash)
        }
    }

    private func open(_ notification: PaveNotification) {
        markRead(notification)
        switch notification.kind {
        case .conversation:
            if let id = notification.conversationID, let onOpenConversation { onOpenConversation(id); return }
        case .verifiedEvidence, .rejectedEvidence:
            if let id = notification.vaultItemID, let onOpenVerifiedEvidence { onOpenVerifiedEvidence(id); return }
        case .verificationRequest:
            break
        }
        openedNotification = notification
    }

    private func delete(_ notification: PaveNotification) {
        PaveHaptics.tap(.medium)
        let all = ids(of: notification)
        undoIDs = all
        Task {
            guard let onDelete else { return }
            for id in all where await !onDelete(id) {
                PaveHaptics.error()
                undoIDs = undoIDs.filter { $0 != id }
            }
        }
    }

    private func undoDelete() {
        let all = undoIDs
        undoIDs = []
        PaveHaptics.success()
        Task { for id in all { _ = await onRestore?(id) } }
    }

    /// Open verification requests first ("Actie nodig": the inbox only holds requests that are still pending), then
    /// everything else by when it happened.
    private var groupedNotifications: [NotificationSection] {
        let calendar = Calendar.current
        let actionable = visibleNotifications.filter { $0.kind == .verificationRequest }
        let rest = visibleNotifications.filter { $0.kind != .verificationRequest }
        let groups = Dictionary(grouping: rest) { item -> String in
            if calendar.isDateInToday(item.date) { return "Vandaag" }
            if let week = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)), item.date >= week {
                return "Deze week"
            }
            return "Eerder"
        }
        var sections: [NotificationSection] = []
        if !actionable.isEmpty {
            sections.append(NotificationSection(title: "Actie nodig", items: actionable, needsAction: true))
        }
        for title in ["Vandaag", "Deze week", "Eerder"] {
            if let items = groups[title], !items.isEmpty {
                sections.append(NotificationSection(title: title, items: items, needsAction: false))
            }
        }
        return sections
    }

    /// A chat row is unread while any of its meldingen is.
    private func isUnread(_ notification: PaveNotification) -> Bool {
        let all = ids(of: notification)
        return inbox.contains { all.contains($0.id) && $0.isUnread && !readIDs.contains($0.id) }
    }

    private func markRead(_ notification: PaveNotification) {
        let all = ids(of: notification)
        readIDs.formUnion(all)
        Task { for id in all { await onMarkRead?(id) } }
    }

    private func markAllRead() {
        PaveHaptics.selection()
        readIDs.formUnion(inbox.map(\.id))
        Task { await onMarkAllRead?() }
    }
}

private struct NotificationSection {
    let title: String
    let items: [PaveNotification]
    let needsAction: Bool
}

private struct VerificationRequestNotificationDetail: View {
    let notification: PaveNotification
    let onLoadReview: ((String) async -> (payload: NotificationReviewPayload?, error: String?))?
    let onResolve: ((String, String, String?) async -> String?)?
    @Environment(\.dismiss) private var dismiss
    @State private var review: NotificationReviewPayload?
    @State private var isLoadingReview = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var previewURL: URL?
    @State private var writesRejection = false
    @State private var isRejected = false

    private var requestID: String? { notification.validationRequestID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Verificatie aanvraag")
                    .textStyle(.calloutTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 10) {
                    Text(initials(notification.personName))
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                        .frame(width: 34, height: 34)
                        .background(Color.panel, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.personName)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                        Text("Verstuurd om \(notification.date.formatted(date: .omitted, time: .shortened))")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))

                if let item = review?.item {
                    vaultItemCard(item)
                    if let description = item.description, !description.isEmpty {
                        detailField("Omschrijving", value: description)
                    }
                    if !item.skills.isEmpty {
                        detailField("Vaardigheden", value: item.skills.joined(separator: " · "))
                    }
                } else {
                    detailField("Naam document", value: notification.documentName ?? notification.title)
                    detailField("Type document", value: notification.documentType ?? "Bewijs")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Document")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    if let files = review?.item.files.filter({ $0.role == "document" }), !files.isEmpty {
                        ForEach(files) { file in
                            Button { Task { await open(file) } } label: {
                                HStack(spacing: 10) {
                                    Image(.iconDocumentText).frame(width: 18, height: 18)
                                    Text(file.name).lineLimit(1)
                                    Spacer()
                                    Image(.iconEyeSolid).renderingMode(.template).resizable().scaledToFit().frame(width: 17, height: 17)
                                }
                                .textStyle(.caption)
                                .foregroundStyle(Color.ink)
                                .padding(12)
                                .background(Color.panel, in: .rect(cornerRadius: 12))
                                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder) }
                            }
                            .buttonStyle(.pave)
                        }
                    } else if isLoadingReview {
                        ProgressView().frame(maxWidth: .infinity).frame(height: 80)
                    } else if review == nil {
                        PaveSecondaryButton(title: "Opnieuw proberen") {
                            Task { await loadReview() }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        documentPlaceholder
                    }
                }

                Text("Controleer het document voordat je het verifieert.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)

                if let errorMessage {
                    Text(errorMessage).textStyle(.caption).foregroundStyle(Color.statusRejected)
                }
                PavePrimaryButton(title: isWorking ? "Bezig…" : "Verifieer document") {
                    Task { await verify() }
                }
                .disabled(isWorking || onResolve == nil || review == nil)
                Button("Aanvraag afwijzen", role: .destructive) { writesRejection = true }
                    .textStyle(.caption)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.pave)
                    .disabled(isWorking || onResolve == nil || review == nil)
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: requestID) { await loadReview() }
        .sheet(isPresented: $writesRejection, onDismiss: {
            // Back to the notifications once the sheet is gone, not while it is still closing.
            if isRejected { dismiss() }
        }) {
            NotificationRejectSheet(documentName: review?.item.title ?? notification.documentName ?? "dit bewijs") { reason in
                guard let requestID, let onResolve else { return Self.notConnected }
                let error = await onResolve(requestID, "rejected", reason)
                if error == nil { isRejected = true }
                return error
            }
        }
        .vaultQuickLook($previewURL)
    }

    private var documentPlaceholder: some View {
        VStack(spacing: 10) {
            Image(.iconDocumentText)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundStyle(Color.inkMuted)
            Text(notification.documentFileName ?? "Documentvoorbeeld")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color.panel, in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder) }
    }

    private func vaultItemCard(_ item: NotificationReviewItem) -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            vaultItemCardArtwork(item)
            vaultItemCardDetails(item)
        }
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
    }

    @ViewBuilder
    private func vaultItemCardArtwork(_ item: NotificationReviewItem) -> some View {
        let tint = VaultCategory(rawValue: item.category)?.tint ?? Color.paveSurfaceTint
        vaultItemArtwork(item, tint: tint)
    }

    @ViewBuilder
    private func vaultItemCardDetails(_ item: NotificationReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(item.title).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(2)
                Spacer(minLength: 4)
                Text("In afwachting").textStyle(.meta).foregroundStyle(Color.statusPending)
            }
            .padding(.top, 28)
            Text(item.categoryTitle).textStyle(.caption).foregroundStyle(Color.inkMuted)
            if let place = organisationPlace(for: item) {
                PaveIconLabel(icon: .iconBuildingOfficeSolid, text: place)
            }
            if let period = item.periodText {
                PaveIconLabel(icon: .iconCalendarDaysSolid, text: period)
            }
        }
        .padding(14)
    }

    private func organisationPlace(for item: NotificationReviewItem) -> String? {
        let parts = [item.organisationName, item.organisationLocation]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func vaultItemArtwork(_ item: NotificationReviewItem, tint: Color) -> some View {
        let logo = item.files.first { $0.role == "logo" }
        let cover = item.files.first { $0.role == "cover" }

        return tint
            .overlay { coverArtwork(cover, tint: tint) }
            .frame(height: 48)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                logoArtwork(logo, item: item)
                    .frame(width: 48, height: 48)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder) }
                    .padding(.leading, 14)
                    .offset(y: 24)
            }
    }

    @ViewBuilder
    private func coverArtwork(_ cover: NotificationReviewFile?, tint: Color) -> some View {
        if let cover, let url = URL(string: cover.url) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                tint
            }
        }
    }

    @ViewBuilder
    private func logoArtwork(_ logo: NotificationReviewFile?, item: NotificationReviewItem) -> some View {
        if let logo, let url = URL(string: logo.url) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                logoFallback(item)
            }
        } else {
            logoFallback(item)
        }
    }

    private func logoFallback(_ item: NotificationReviewItem) -> some View {
        Text(String((item.organisationName ?? item.title).prefix(1)).uppercased())
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.paveAccent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.panel)
    }

    private func loadReview() async {
        guard let requestID, let onLoadReview else {
            isLoadingReview = false
            return
        }
        isLoadingReview = true
        errorMessage = nil
        let result = await onLoadReview(requestID)
        review = result.payload
        errorMessage = result.error
        isLoadingReview = false
    }

    private func open(_ file: NotificationReviewFile) async {
        guard let url = URL(string: file.url), let (temporary, _) = try? await URLSession.shared.download(from: url),
              let data = try? Data(contentsOf: temporary), let localURL = VaultPreviewFile.url(for: data, named: file.name) else {
            errorMessage = "Het document kon niet worden geopend."
            return
        }
        previewURL = localURL
    }

    private static let notConnected = "Beoordelen werkt nu niet. Probeer het later opnieuw."

    private func verify() async {
        guard let requestID, let onResolve else { return }
        isWorking = true
        errorMessage = nil
        let error = await onResolve(requestID, "verified", nil)
        isWorking = false
        if let error {
            errorMessage = error
            PaveHaptics.error()
        } else {
            PaveHaptics.success()
            dismiss()
        }
    }

    private func detailField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            Text(value)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

private struct NotificationMessageDetail: View {
    let notification: PaveNotification

    var body: some View {
        PaveEmptyState(
            icon: notification.kind.icon,
            title: notification.title,
            message: notification.personName
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Melding")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Meldingen · lerende") {
    NotificationsScreen(onShowMenu: {}, audience: .learner, notifications: PaveNotification.previewLearner)
}

#Preview("Meldingen · admin") {
    NotificationsScreen(onShowMenu: {}, audience: .administrator, notifications: PaveNotification.previewAdmin)
}

#Preview("Meldingen · aanvraagdetail") {
    NavigationStack {
        VerificationRequestNotificationDetail(
            notification: PaveNotification.previewAdmin[0],
            onLoadReview: nil,
            onResolve: nil
        )
    }
}

#Preview("Meldingen · veel (lerende)") {
    NotificationsScreen(onShowMenu: {}, audience: .learner, notifications: PaveNotification.previewManyLearner)
}

#Preview("Meldingen · veel (admin)") {
    NotificationsScreen(onShowMenu: {}, audience: .administrator, notifications: PaveNotification.previewManyAdmin)
}

private extension PaveNotification {
    /// `hours` ago, so the rows land in Vandaag, Deze week and Eerder.
    static func sample(
        _ id: String, _ kind: PaveNotificationKind, _ title: String, _ person: String, hours: Double,
        unread: Bool = true, deleted: Bool = false, chat: String? = nil,
        learner: String? = nil, document: String? = nil, type: String? = nil
    ) -> PaveNotification {
        .init(
            id: id, kind: kind, title: title, personName: person, date: .now.addingTimeInterval(-hours * 3600),
            isUnread: unread, deletedAt: deleted ? .now.addingTimeInterval(-3600) : nil, conversationID: chat,
            vaultItemID: kind == .conversation ? nil : "preview-item",
            learnerName: learner, learnerOrganization: learner == nil ? nil : "Middelbaar College",
            documentName: document, documentType: type, documentFileName: document == nil ? nil : "\(document!).pdf"
        )
    }

    /// A chat with several meldingen, which the inbox shows as one row with a count.
    static func chat(_ chat: String, _ title: String, count: Int, hours: Double, unread: Bool = true) -> [PaveNotification] {
        (0..<count).map { sample("\(chat)-\($0)", .conversation, title, "Ayla", hours: hours + Double($0), unread: unread, chat: chat) }
    }

    static var previewManyLearner: [PaveNotification] {
        [
            sample("v1", .verifiedEvidence, "Bewijs geverifieerd", "Fontys Hogescholen", hours: 0.2),
            sample("r1", .rejectedEvidence, "Bewijs afgewezen", "Middelbaar College", hours: 1.5),
            sample("v2", .verifiedEvidence, "Bewijs geverifieerd", "Albeda", hours: 5, unread: false),
            sample("v3", .verifiedEvidence, "Bewijs geverifieerd", "Hogeschool Rotterdam", hours: 30),
            sample("r2", .rejectedEvidence, "Bewijs afgewezen", "Fontys Hogescholen", hours: 52, unread: false),
            sample("v4", .verifiedEvidence, "Bewijs geverifieerd", "Middelbaar College", hours: 200, unread: false),
            sample("r3", .rejectedEvidence, "Bewijs afgewezen", "Albeda", hours: 400, unread: false),
            sample("gone1", .verifiedEvidence, "Bewijs geverifieerd", "Fontys Hogescholen", hours: 90, deleted: true),
        ]
        + chat("c1", "Ik doe een cursus over design", count: 3, hours: 0.5)
        + chat("c2", "Kun je een item toevoegen in mijn kluis", count: 14, hours: 26)
        + chat("c3", "Bekijk deze bestanden", count: 5, hours: 75, unread: false)
        + chat("c4", "Sollicitatie bij Coolblue voorbereiden", count: 1, hours: 300, unread: false)
    }

    static var previewManyAdmin: [PaveNotification] {
        [
            sample("q1", .verificationRequest, "Verificatie aanvraag", "Gianna Beenen", hours: 0.3,
                   learner: "Gianna Beenen", document: "Toets Nederlands grammatica", type: "Toetsen Middelbaar"),
            sample("q2", .verificationRequest, "Verificatie aanvraag", "Ravi Sharma", hours: 4,
                   learner: "Ravi Sharma", document: "Hbo-ICT propedeuse", type: "Diploma"),
            sample("q3", .verificationRequest, "Verificatie aanvraag", "Noor El Amrani", hours: 48, unread: false,
                   learner: "Noor El Amrani", document: "Stage bij Rabobank", type: "Stage"),
            sample("v1", .verifiedEvidence, "Bewijs geverifieerd", "Fontys Hogescholen", hours: 6),
            sample("r1", .rejectedEvidence, "Bewijs afgewezen", "Albeda", hours: 100, unread: false),
            sample("gone1", .conversation, "Oud gesprek", "Ayla", hours: 90, deleted: true, chat: "old"),
        ]
        + chat("c1", "Gesprek voor stage", count: 4, hours: 2)
        + chat("c2", "Feedback op portfolio", count: 2, hours: 28, unread: false)
        + chat("c3", "Vragen over verificatie", count: 1, hours: 250, unread: false)
    }

    static var previewLearner: [PaveNotification] {
        [
            .init(id: "verified-1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Middelbaar College", date: .now.addingTimeInterval(-3600), vaultItemID: "preview-item"),
            .init(id: "rejected-1", kind: .rejectedEvidence, title: "Bewijs afgewezen", personName: "Middelbaar College", date: .now.addingTimeInterval(-7200), vaultItemID: "preview-item"),
            .init(id: "chat-1", kind: .conversation, title: "Gesprek voor stage", personName: "Ayla", date: .now.addingTimeInterval(-86_400), conversationID: "preview-chat"),
        ]
    }

    static var previewAdmin: [PaveNotification] {
        [
            .init(id: "request-1", kind: .verificationRequest, title: "Verificatie aanvraag", personName: "Gianna Beenen", date: .now.addingTimeInterval(-3600), learnerName: "Gianna Beenen", learnerOrganization: "Middelbaar College", documentName: "Toets Nederlands grammatica.", documentType: "Toetsen Middelbaar", documentFileName: "Nederlands.pdf"),
            .init(id: "chat-2", kind: .conversation, title: "Gesprek voor stage", personName: "Gianna Beenen", date: .now.addingTimeInterval(-86_400), conversationID: "preview-chat"),
        ]
    }
}
