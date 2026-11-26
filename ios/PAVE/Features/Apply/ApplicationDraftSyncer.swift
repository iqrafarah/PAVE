import Foundation
import PAVECore

/// Keeps the applications on this device and those of the account the same, so a draft started here goes on on
/// another device. The app keeps working from the device; this only moves what is newer, a whole application at a time.
@MainActor
final class ApplicationDraftSyncer {
    private let service: any ApplicationDraftService
    private let accountID: @Sendable () async -> String?
    private let store: ApplicationStore
    private var isRunning = false

    init(service: any ApplicationDraftService, store: ApplicationStore = ApplicationStore(), accountID: @escaping @Sendable () async -> String?) {
        self.service = service
        self.store = store
        self.accountID = accountID
    }

    /// Nil for the demo login or without a Supabase project: applications then stay on this device.
    static func make(auth: any AuthService, bundle: Bundle = .main) -> ApplicationDraftSyncer? {
        guard
            !(auth is MockAuthService),
            let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: urlString), url.host() != nil,
            let key = bundle.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
            !key.isEmpty
        else { return nil }
        let service = SupabaseApplicationDraftService(projectURL: url, publishableKey: key) { await auth.accessToken() }
        return ApplicationDraftSyncer(service: service) { await auth.accountID() }
    }

    /// One round. True when something on this device changed, so lists can read again. Without a connection or before
    /// the table exists nothing happens; the next round tries again.
    @discardableResult
    func run() async -> Bool {
        guard !isRunning, let account = await accountID(), store.claim(for: account) else { return false }
        isRunning = true
        defer { isRunning = false }
        guard let remote = try? await service.all() else { return false }
        let plan = ApplicationDraftSync.plan(local: store.all(), deletedLocally: store.deletions(), remote: remote)
        plan.download.forEach { store.save($0) }
        plan.removeLocally.forEach { store.remove($0) }
        store.forgetDeletions(plan.settled)
        for draft in plan.upload { try? await service.save(draft) }
        for (id, date) in plan.deleteRemotely where (try? await service.delete(id: id, at: date)) != nil {
            store.forgetDeletions([id])
        }
        return !plan.download.isEmpty || !plan.removeLocally.isEmpty
    }
}
