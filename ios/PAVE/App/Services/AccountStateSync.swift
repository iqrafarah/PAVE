import Foundation
import PAVECore

/// Keeps what a person keeps in PAVE besides evidence, plans, chats and applications the same on every device they
/// sign in on, through `account_state` in Supabase: Mijn beursdag, what was seen, choices on Ayla's plan proposals, the
/// vault's folders, pinned and muted mail and the last sharing choices. The app keeps working from its copy on the
/// device (per account, `PaveAccount`); this compares it with the account's, each thing on its own. Before the table
/// exists nothing happens and everything stays on the device.
@MainActor
final class AccountStateSync {
    /// One thing, where it lives on the device and how two copies come together.
    struct Item: Sendable {
        enum Stored: Sendable { case plain, date, json }
        let scope: String
        let key: String
        let localKey: String
        let merge: AccountStateMerge
        var stored: Stored = .plain
        var id: String { "\(scope)/\(key)" }
    }

    static let items: [Item] = [
        Item(scope: "fairDay", key: "entries", localKey: "fair.day", merge: .unionByDate, stored: .json),
        Item(scope: "seen", key: "fairInvitations", localKey: "fair.seenInvitations", merge: .unionOfStrings),
        Item(scope: "seen", key: "shareLooksUntil", localKey: "shareLooksSeenUntil", merge: .latestDate, stored: .date),
        Item(scope: "planEdit", key: "decisions", localKey: "aylaPlanEditDecisions", merge: .unionOfKeys),
        Item(scope: "vault", key: "folderStyles", localKey: "vaultFolderStyles", merge: .unionOfKeys),
        Item(scope: "vault", key: "folderOrder", localKey: "vaultFolderOrder", merge: .newest),
        Item(scope: "vault", key: "itemOrder", localKey: "vaultItemOrder", merge: .newest),
        Item(scope: "vault", key: "exampleFoldersMade", localKey: "vaultExampleFoldersMade", merge: .newest),
        Item(scope: "mail", key: "pinned", localKey: "emailPinnedThreads", merge: .newest),
        Item(scope: "mail", key: "muted", localKey: "emailMutedThreads", merge: .newest),
        Item(scope: "mail", key: "locked", localKey: "emailLockedThreads", merge: .newest),
        Item(scope: "choices", key: "quickShareProfile", localKey: "quickShare.profileID", merge: .newest),
        Item(scope: "choices", key: "fairAvailability", localKey: "fair.availability", merge: .newest),
    ]

    /// Something came in from another device: models that read these once (the plan's proposals, pinned mail) read again.
    static let didPull = Notification.Name("accountStateDidPull")

    private let service: any AccountStateService
    private let defaults: UserDefaults
    private let items: [Item]
    private let now: () -> Date
    private var isRunning = false
    private var isWriting = false
    private var pending: Task<Void, Never>?
    /// The table is not there yet: no more asking until the app starts again.
    private(set) var isAvailable = true

    init(service: any AccountStateService, defaults: UserDefaults = .standard, items: [Item] = AccountStateSync.items, now: @escaping () -> Date = { .now }) {
        self.service = service
        self.defaults = defaults
        self.items = items
        self.now = now
    }

    /// Nil for the demo login or without a Supabase project.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> AccountStateSync? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else { return nil }
        return AccountStateSync(service: SupabaseAccountStateService(projectURL: url, publishableKey: key) { await auth.accessToken() })
    }

    /// Something changed on the device: compared with the account a moment later, so a burst of changes is one round.
    func localChanged() {
        guard !isWriting, isAvailable, PaveAccount.current(in: defaults) != nil, noteLocalChanges() else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.run()
        }
    }

    /// One round: what is newer on the device goes to the account, what is newer in the account comes here.
    @discardableResult
    func run() async -> Bool {
        guard !isRunning, isAvailable, let account = PaveAccount.current(in: defaults) else { return false }
        isRunning = true
        defer { isRunning = false }
        noteLocalChanges()
        let remote: [AccountStateRow]
        do {
            remote = try await service.all()
        } catch AccountStateServiceError.notSetUp {
            isAvailable = false
            return false
        } catch {
            return false
        }
        // Signed out or another account while waiting: nothing of the one goes to the other.
        guard PaveAccount.current(in: defaults) == account else { return false }
        let byID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a.updatedAt > b.updatedAt ? a : b })
        var synced = syncedValues
        var changed = changedAt
        var outgoing: [AccountStateRow] = []
        var pulled = false
        for item in items {
            let localKey = PaveAccount.key(item.localKey, in: defaults)
            let local = Self.json(of: defaults.object(forKey: localKey), stored: item.stored)
            let row = byID[item.id]
            let remoteValue = row.flatMap { try? JSONSerialization.jsonObject(with: $0.value, options: .fragmentsAllowed) }
            let merged = item.merge.merge(local: local, localAt: changed[item.id].map(Date.init(timeIntervalSince1970:)), remote: remoteValue, remoteAt: row?.updatedAt)
            guard let merged, let mergedText = Self.text(merged) else { continue }
            if mergedText != local.flatMap(Self.text) {
                isWriting = true
                defaults.set(Self.stored(merged, as: item.stored), forKey: localKey)
                isWriting = false
                pulled = true
            }
            if mergedText != remoteValue.flatMap(Self.text), let data = mergedText.data(using: .utf8) {
                outgoing.append(AccountStateRow(scope: item.scope, key: item.key, value: data, updatedAt: max(now(), row?.updatedAt ?? .distantPast)))
            }
            synced[item.id] = mergedText
            changed[item.id] = nil
        }
        if !outgoing.isEmpty {
            do {
                try await service.save(outgoing)
            } catch {
                return pulled
            }
        }
        guard PaveAccount.current(in: defaults) == account else { return false }
        syncedValues = synced
        changedAt = changed
        if pulled { NotificationCenter.default.post(name: Self.didPull, object: nil) }
        return pulled
    }

    /// When each thing changed on the device since the last round, so the newest copy wins.
    /// True when one of them differs from what the account had at the last round.
    @discardableResult
    private func noteLocalChanges() -> Bool {
        let synced = syncedValues
        var changed = changedAt
        var differs = false
        for item in items {
            let local = Self.json(of: defaults.object(forKey: PaveAccount.key(item.localKey, in: defaults)), stored: item.stored).flatMap(Self.text)
            guard local != synced[item.id], local != nil else { continue }
            differs = true
            if changed[item.id] == nil { changed[item.id] = now().timeIntervalSince1970 }
        }
        if changed != changedAt {
            isWriting = true
            changedAt = changed
            isWriting = false
        }
        return differs
    }

    // MARK: Kept per account

    private var syncedValues: [String: String] {
        get { defaults.dictionary(forKey: PaveAccount.key("accountState.synced", in: defaults)) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: PaveAccount.key("accountState.synced", in: defaults)) }
    }

    private var changedAt: [String: Double] {
        get { defaults.dictionary(forKey: PaveAccount.key("accountState.changed", in: defaults)) as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: PaveAccount.key("accountState.changed", in: defaults)) }
    }

    // MARK: Values

    static func json(of object: Any?, stored: Item.Stored) -> Any? {
        guard let object else { return nil }
        switch stored {
        case .plain: return object
        case .date: return (object as? Date).map { $0.formatted(.iso8601) }
        case .json: return (object as? Data).flatMap { try? JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed) }
        }
    }

    static func stored(_ json: Any, as stored: Item.Stored) -> Any? {
        switch stored {
        case .plain: return json
        case .date: return (json as? String).flatMap { try? Date.ISO8601FormatStyle().parse($0) }
        case .json: return try? JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        }
    }

    static func text(_ json: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .fragmentsAllowed]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
