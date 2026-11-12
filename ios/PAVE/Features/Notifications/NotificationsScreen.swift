import SwiftUI

enum NotificationAudience {
    case learner
    case administrator
}

enum PaveNotificationKind: String, CaseIterable, Hashable, Identifiable {
    case conversation
    case verifiedEvidence
    case verificationRequest

    var id: Self { self }

    var title: String {
        switch self {
        case .conversation: "Gesprek"
        case .verifiedEvidence: "Verificatie"
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
        case .verificationRequest: "Aanvragen die je kunt beoordelen"
        }
    }

    var icon: ImageResource {
        switch self {
        case .conversation: .iconChat
        case .verifiedEvidence, .verificationRequest: .iconCheckBadgeSolid
        }
    }
}

struct PaveNotification: Identifiable, Hashable {
    let id: String
    let kind: PaveNotificationKind
    let title: String
    let personName: String
    let date: Date
    var isUnread = true
    var conversationID: String?
    var vaultItemID: String?
    var learnerName: String?
    var learnerOrganization: String?
    var documentName: String?
    var documentType: String?
    var documentFileName: String?
}

struct NotificationsScreen: View {
    let onShowMenu: (() -> Void)?
    var audience: NotificationAudience = .learner
    var notifications: [PaveNotification] = []
    var onOpenConversation: ((String) -> Void)?
    var onOpenVerifiedEvidence: ((String) -> Void)?
    var onOpenVerificationDocument: ((PaveNotification) -> Void)?
    var onVerifyRequest: ((PaveNotification) -> Void)?

    @State private var tab: NotificationTab = .all
    @State private var selectedKinds: Set<PaveNotificationKind> = []
    @State private var hasKindFilter = false
    @State private var searchText = ""
    @State private var showsFilters = false
    @State private var openedNotification: PaveNotification?
    @State private var readIDs: Set<String> = []

    private var availableKinds: [PaveNotificationKind] {
        switch audience {
        case .learner: [.conversation, .verifiedEvidence]
        case .administrator: [.conversation, .verificationRequest]
        }
    }

    private var activeKinds: Set<PaveNotificationKind> {
        hasKindFilter ? selectedKinds : Set(availableKinds)
    }

    private var visibleNotifications: [PaveNotification] {
        notifications
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
        notifications.filter { availableKinds.contains($0.kind) && isUnread($0) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    intro
                    tabs
                    search
                    if hasKindFilter, !selectedKinds.isEmpty {
                        activeFilterChips
                    }
                    notificationList
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar("Meldingen", onShowMenu: onShowMenu)
            .sheet(isPresented: $showsFilters) {
                NotificationFilterSheet(
                    audience: audience,
                    selectedKinds: $selectedKinds,
                    hasKindFilter: $hasKindFilter,
                    resultCount: notifications.filter { availableKinds.contains($0.kind) && activeKinds.contains($0.kind) }.count
                )
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.white)
            }
            .navigationDestination(isPresented: Binding(
                get: { openedNotification != nil },
                set: { if !$0 { openedNotification = nil } }
            )) {
                if let notification = openedNotification {
                    if notification.kind == .verificationRequest {
                        VerificationRequestNotificationDetail(
                            notification: notification,
                            onOpenDocument: onOpenVerificationDocument,
                            onVerify: onVerifyRequest
                        )
                    } else {
                        NotificationMessageDetail(notification: notification)
                    }
                }
            }
        }
        .tint(.brandGreen)
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
                        .background(tab == option ? Color.brandGreen : Color.surfaceTint, in: .capsule)
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
                    .background(Color.surfaceTint, in: .rect(cornerRadius: 11))
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
                        PaveHaptics.selection()
                    } label: {
                        HStack(spacing: 7) {
                            Text(kind.filterTitle)
                            Image(.iconXMark)
                                .resizable()
                                .frame(width: 10, height: 10)
                        }
                        .textStyle(.caption)
                        .foregroundStyle(Color.brandGreen)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.surfaceTint, in: .capsule)
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
            PaveEmptyState(
                icon: searchText.isEmpty ? .iconMailOpen : .iconSearch,
                title: searchText.isEmpty ? "Je bent helemaal bij" : "Geen meldingen gevonden",
                message: searchText.isEmpty ? "Nieuwe meldingen verschijnen hier." : "Pas je zoekopdracht of filters aan."
            )
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(groupedNotifications, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(section.title)
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                            Spacer()
                            Text(section.countLabel)
                                .textStyle(.caption)
                                .foregroundStyle(Color.brandGreen)
                        }
                        ForEach(section.items) { notification in
                            row(notification)
                        }
                    }
                }
            }
        }
    }

    private func row(_ notification: PaveNotification) -> some View {
        let content = HStack(alignment: .center, spacing: 11) {
            Image(notification.kind.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.brandGreen)
                .frame(width: 20, height: 20)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.85), in: .rect(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text(notification.personName)
                    .textStyle(.caption)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                HStack {
                    Text(notification.date.formatted(date: .omitted, time: .shortened))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    Spacer(minLength: 6)
                    Text(notification.kind == .conversation ? "Bekijk gesprek" : "Bekijk aanvraag")
                        .textStyle(.caption)
                        .foregroundStyle(Color.brandGreen)
                    Image(.iconArrowRight)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.brandGreen)
                }
            }
            Spacer(minLength: 0)
            if isUnread(notification) {
                Circle().fill(Color.brandGreen).frame(width: 6, height: 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(isUnread(notification) ? Color.surfaceTint : Color.white, in: .rect(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(Color.cardBorder) }
        .contentShape(.rect(cornerRadius: 13))

        return Group {
            if notification.kind == .conversation, let id = notification.conversationID, let onOpenConversation {
                Button {
                    markRead(notification)
                    onOpenConversation(id)
                } label: { content }
                .buttonStyle(.pave)
            } else if notification.kind == .verifiedEvidence, let id = notification.vaultItemID, let onOpenVerifiedEvidence {
                Button {
                    markRead(notification)
                    onOpenVerifiedEvidence(id)
                } label: { content }
                .buttonStyle(.pave)
            } else {
                Button {
                    markRead(notification)
                    openedNotification = notification
                } label: { content }
                .buttonStyle(.pave)
            }
        }
        .accessibilityElement(children: .combine)
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
    let audience: NotificationAudience
    @Binding var selectedKinds: Set<PaveNotificationKind>
    @Binding var hasKindFilter: Bool
    let resultCount: Int
    @Environment(\.dismiss) private var dismiss

    private var availableKinds: [PaveNotificationKind] {
        switch audience {
        case .learner: [.verifiedEvidence, .conversation]
        case .administrator: [.verificationRequest, .conversation]
        }
    }

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
                        .background(Color.white, in: .rect(cornerRadius: 12))
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
            .foregroundStyle(Color.brandGreen)
            .frame(maxWidth: .infinity)
            .buttonStyle(.pave)
        }
        .padding(22)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .paveSheet()
    }
}

private struct VerificationRequestNotificationDetail: View {
    let notification: PaveNotification
    let onOpenDocument: ((PaveNotification) -> Void)?
    let onVerify: ((PaveNotification) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { dismiss() } label: {
                    Label("Terug naar meldingen", image: .iconArrowLeft)
                        .textStyle(.caption)
                        .foregroundStyle(Color.brandGreen)
                }
                .buttonStyle(.pave)

                Text("Verificatie aanvraag")
                    .textStyle(.calloutTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 10) {
                    Text(initials(notification.personName))
                        .textStyle(.caption)
                        .foregroundStyle(Color.brandGreen)
                        .frame(width: 34, height: 34)
                        .background(Color.white, in: .circle)
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
                .background(Color.surfaceTint, in: .rect(cornerRadius: 12))

                detailField("Naam document", value: notification.documentName ?? notification.title)
                detailField("Type document", value: notification.documentType ?? "Bewijs")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Document")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    documentPlaceholder
                    Button {
                        onOpenDocument?(notification)
                    } label: {
                        Label("Bekijk volledig document", image: .iconEye)
                            .textStyle(.caption)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pave)
                    .disabled(notification.documentFileName == nil || onOpenDocument == nil)
                }

                Text("Controleer het document voordat je het verifieert.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)

                PavePrimaryButton(title: "Verifieer document") { onVerify?(notification) }
                    .disabled(onVerify == nil)
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
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
        .background(Color.white, in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder) }
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
            onOpenDocument: nil,
            onVerify: nil
        )
    }
}

private extension PaveNotification {
    static var previewLearner: [PaveNotification] {
        [
            .init(id: "verified-1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Middelbaar College", date: .now.addingTimeInterval(-3600), vaultItemID: "preview-item"),
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
