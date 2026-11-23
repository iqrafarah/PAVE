import PAVECore
import SwiftUI

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
        case .verifiedEvidence, .verificationRequest: .iconCheckBadgeSolid
        case .rejectedEvidence: .iconExclamationCircle
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
    var onOpenConversation: ((String) -> Void)?
    var onOpenVerifiedEvidence: ((String) -> Void)?
    var onLoadReview: ((String) async -> (payload: NotificationReviewPayload?, error: String?))?
    var onResolveRequest: ((String, String, String?) async -> String?)?
    /// Both report whether the server saved it; the model puts the notification back if not.
    var onDelete: ((String) async -> Bool)?
    var onRestore: ((String) async -> Bool)?

    @State private var tab: NotificationTab = .all
    @State private var selectedKinds: Set<PaveNotificationKind> = []
    @State private var hasKindFilter = false
    @State private var searchText = ""
    @State private var showsFilters = false
    @State private var showsTrash = false
    @State private var openedNotification: PaveNotification?
    @State private var readIDs: Set<String> = []
    /// The notification just deleted, while "Ongedaan maken" is on screen.
    @State private var undoID: String?

    /// What the role normally gets, plus whatever is actually in the inbox: a reviewer who also asks for verification
    /// still sees the decisions on their own evidence.
    private var availableKinds: [PaveNotificationKind] {
        let usual: Set<PaveNotificationKind> = switch audience {
        case .learner: [.conversation, .verifiedEvidence, .rejectedEvidence]
        case .administrator: [.conversation, .verificationRequest]
        }
        let present = Set(inbox.map(\.kind))
        return [.verificationRequest, .verifiedEvidence, .rejectedEvidence, .conversation].filter { usual.contains($0) || present.contains($0) }
    }

    private var activeKinds: Set<PaveNotificationKind> {
        hasKindFilter ? selectedKinds : Set(availableKinds)
    }

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
            .filter { availableKinds.contains($0.kind) && activeKinds.contains($0.kind) }
            .filter { tab == .all || isUnread($0) }
            .filter {
                searchText.isEmpty || [
                    $0.title, $0.personName, $0.documentName ?? "", $0.documentType ?? ""
                ].joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.date > $1.date }
    }

    private var unreadCount: Int {
        inbox.filter { availableKinds.contains($0.kind) && isUnread($0) }.count
    }

    var body: some View {
        NavigationStack {
            // A List, not a ScrollView, because only a List has swipe actions.
            List {
                Group {
                    intro
                    if let loadError {
                        Text(loadError)
                            .textStyle(.caption)
                            .foregroundStyle(Color.statusRejected)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.panel, in: .rect(cornerRadius: 12))
                    }
                    tabs
                    search
                    if hasKindFilter, !selectedKinds.isEmpty {
                        activeFilterChips
                    }
                }
                .notificationListRow()
                notificationList
                if !deletedNotifications.isEmpty {
                    trashLink
                        .notificationListRow(top: 16, bottom: 32)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .contentMargins(.top, 8, for: .scrollContent)
            .animation(.snappy, value: visibleNotifications.map(\.id))
            .refreshable { await onRefresh?() }
            .safeAreaInset(edge: .bottom, spacing: 12) {
                if undoID != nil {
                    AylaUndoBar(message: "Melding verwijderd") { undoDelete() }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: 560)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: undoID)
            .task(id: undoID) {
                guard undoID != nil else { return }
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                undoID = nil
            }
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Meldingen", onShowMenu: onShowMenu)
            .sheet(isPresented: $showsFilters, onDismiss: {
                // Nothing ticked means no filter, so the list never ends up empty without a way back.
                if selectedKinds.isEmpty { hasKindFilter = false }
            }) {
                NotificationFilterSheet(
                    availableKinds: availableKinds,
                    selectedKinds: $selectedKinds,
                    hasKindFilter: $hasKindFilter,
                    resultCount: inbox.filter { availableKinds.contains($0.kind) && activeKinds.contains($0.kind) }.count
                )
                // One row per kind: a reviewer who also asks for verification can have all four.
                .presentationDetents([.height(availableKinds.count > 3 ? 454 : 390)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.panel)
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
                            onResolve: onResolveRequest
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
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Je meldingen")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Alles wat jouw aandacht nodig heeft.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(NotificationTab.allCases) { option in
                Button {
                    tab = option
                    PaveHaptics.selection()
                } label: {
                    Text(option.title(unreadCount: unreadCount))
                        .textStyle(.caption)
                        .foregroundStyle(tab == option ? Color.white : Color.inkMuted)
                        .padding(.horizontal, 13)
                        .frame(height: 34)
                        .background(tab == option ? Color.paveAccentFill : Color.paveSurfaceTint, in: .capsule)
                }
                .buttonStyle(.pave)
            }
            Spacer(minLength: 0)
        }
    }

    private var search: some View {
        HStack(spacing: 8) {
            PaveSearchField(text: $searchText, prompt: "Zoek in meldingen")
            Button { showsFilters = true } label: {
                Image(.iconFunnelSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.ink)
                    .frame(width: 17, height: 17)
                    .frame(width: 40, height: 40)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 11))
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Meldingen filteren")
        }
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(Array(activeKinds).sorted { $0.rawValue < $1.rawValue }) { kind in
                    Button {
                        selectedKinds.remove(kind)
                        if selectedKinds.isEmpty { hasKindFilter = false }
                        PaveHaptics.selection()
                    } label: {
                        HStack(spacing: 7) {
                            Text(kind.filterTitle)
                            Image(.iconXMark)
                                .resizable()
                                .frame(width: 10, height: 10)
                        }
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.paveSurfaceTint, in: .capsule)
                    }
                    .buttonStyle(.pave)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var notificationList: some View {
        if visibleNotifications.isEmpty {
            let isFiltered = !searchText.isEmpty || hasKindFilter
            PaveEmptyState(
                icon: isFiltered ? .iconSearch : .iconMailOpen,
                title: isFiltered ? "Geen meldingen gevonden" : "Je bent helemaal bij",
                message: isFiltered ? "Pas je zoekopdracht of filters aan." : "Nieuwe meldingen verschijnen hier."
            )
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
            .notificationListRow()
        } else {
            ForEach(groupedNotifications, id: \.title) { section in
                HStack {
                    Text(section.title)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    Spacer()
                    Text(section.countLabel)
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                }
                .accessibilityAddTraits(.isHeader)
                .notificationListRow(top: 12, bottom: 4)
                ForEach(section.items) { notification in
                    row(notification)
                }
            }
        }
    }

    /// Opens the notification; swipe left or hold it to delete.
    private func row(_ notification: PaveNotification) -> some View {
        Button { open(notification) } label: {
            NotificationRow(notification: notification, isUnread: isUnread(notification), hint: hint(for: notification))
        }
        .buttonStyle(.pave)
        .notificationListRow(top: 4, bottom: 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(notification) } label: {
                Label("Verwijderen", image: .iconTrash)
            }
            // Red, not the app's green tint.
            .tint(.red)
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

    private var trashLink: some View {
        Button { showsTrash = true } label: {
            HStack(spacing: 11) {
                Image(.iconTrash)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.inkMuted)
                Text("Recent verwijderd")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 6)
                Text("\(deletedNotifications.count)")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(Color.panel, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder) }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Recent verwijderd, \(deletedNotifications.count)")
        .accessibilityHint("Verwijderde meldingen kun je \(PaveNotification.restorableDays) dagen terugzetten")
    }

    private func hint(for notification: PaveNotification) -> String {
        switch notification.kind {
        case .conversation: "Bekijk gesprek"
        case .verifiedEvidence, .rejectedEvidence: "Bekijk bewijs"
        case .verificationRequest: "Bekijk aanvraag"
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
        undoID = notification.id
        Task {
            guard let onDelete else { return }
            if await !onDelete(notification.id) {
                PaveHaptics.error()
                if undoID == notification.id { undoID = nil }
            }
        }
    }

    private func undoDelete() {
        guard let id = undoID else { return }
        undoID = nil
        PaveHaptics.success()
        Task { _ = await onRestore?(id) }
    }

    private var groupedNotifications: [NotificationSection] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleNotifications) { item -> String in
            if calendar.isDateInToday(item.date) { return "Vandaag" }
            if calendar.isDateInYesterday(item.date) { return "Gisteren" }
            return "Eerder"
        }
        return ["Vandaag", "Gisteren", "Eerder"].compactMap { title in
            guard let items = groups[title], !items.isEmpty else { return nil }
            return NotificationSection(
                title: title,
                items: items,
                countLabel: title == "Vandaag" ? "\(items.filter(isUnread).count) ongelezen" : ""
            )
        }
    }

    private func isUnread(_ notification: PaveNotification) -> Bool {
        notification.isUnread && !readIDs.contains(notification.id)
    }

    private func markRead(_ notification: PaveNotification) {
        readIDs.insert(notification.id)
        Task { await onMarkRead?(notification.id) }
    }
}

private enum NotificationTab: String, CaseIterable, Identifiable {
    case all
    case unread

    var id: Self { self }

    func title(unreadCount: Int) -> String {
        switch self {
        case .all: "Alle meldingen"
        case .unread: "Ongelezen (\(unreadCount))"
        }
    }
}

private struct NotificationSection {
    let title: String
    let items: [PaveNotification]
    let countLabel: String
}

private struct NotificationFilterSheet: View {
    let availableKinds: [PaveNotificationKind]
    @Binding var selectedKinds: Set<PaveNotificationKind>
    @Binding var hasKindFilter: Bool
    let resultCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(Color.railBorder).frame(width: 38, height: 4).frame(maxWidth: .infinity)
            Text("Meldingen filteren")
                .textStyle(.choice)
                .foregroundStyle(Color.ink)
            Text("Kies welke meldingen je wilt zien.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.top, -13)

            Text("Type melding")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)

            VStack(spacing: 8) {
                ForEach(availableKinds) { kind in
                    Button {
                        var selection = hasKindFilter ? selectedKinds : Set(availableKinds)
                        if selection.contains(kind) {
                            selection.remove(kind)
                        } else {
                            selection.insert(kind)
                        }
                        hasKindFilter = true
                        selectedKinds = selection
                        PaveHaptics.selection()
                    } label: {
                        HStack(spacing: 11) {
                            Image(kind.icon)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(Color.ink)
                                .frame(width: 16, height: 16)
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.filterTitle)
                                    .textStyle(.bodyMedium)
                                    .foregroundStyle(Color.ink)
                                Text(kind.description)
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.inkMuted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            PaveCheckbox(isOn: (hasKindFilter ? selectedKinds : Set(availableKinds)).contains(kind), size: 18)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 56)
                        .background(Color.panel, in: .rect(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder) }
                        .contentShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.pave)
                }
            }

            PavePrimaryButton(title: "Toon \(resultCount) meldingen") { dismiss() }
            Button("Wis filters") {
                selectedKinds.removeAll()
                hasKindFilter = false
                PaveHaptics.selection()
            }
            .textStyle(.caption)
            .foregroundStyle(Color.paveAccent)
            .frame(maxWidth: .infinity)
            .buttonStyle(.pave)
        }
        .padding(22)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .background(Color.panel.ignoresSafeArea())
        .paveSheet()
    }
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
    /// Verified: the status of the evidence turns and the button becomes the confirmation, for a moment before it closes.
    @State private var isVerified = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    private var requestID: String? { notification.validationRequestID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { dismiss() } label: {
                    Label("Terug naar meldingen", image: .iconArrowLeft)
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                }
                .buttonStyle(.pave)

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
                                    Image(.iconEye).frame(width: 17, height: 17)
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
                if isVerified {
                    verifiedConfirmation
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                } else {
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
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
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
                if isVerified {
                    VaultStatusMorph(from: .init(status: .toVerify, isAwaitingReview: true), to: .init(status: .verified), delay: .milliseconds(120))
                } else {
                    VaultStatusBadge(status: .toVerify, isAwaitingReview: true)
                }
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
            AccessibilityNotification.Announcement(VaultMessages.reviewVerified).post()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.3)) { isVerified = true }
            // A moment to see it turn, as at the end of the wallet; then back to the notifications.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 500 : 900))
            dismiss()
        }
    }

    /// In place of the buttons once the evidence is verified: the same shape as the button, with the tick of a
    /// confirmed item.
    private var verifiedConfirmation: some View {
        HStack(spacing: 10) {
            Image(.iconCheckBadgeSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(VaultMessages.reviewVerified)
                .textStyle(.button)
        }
        .foregroundStyle(Color.paveAccent)
        .frame(maxWidth: .infinity, minHeight: 53)
        .background(Color.paveVerifiedSurface, in: .capsule)
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

private extension PaveNotification {
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
