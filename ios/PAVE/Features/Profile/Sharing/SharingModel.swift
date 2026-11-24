import Foundation
import Observation
import PAVECore
import UIKit

/// Your shares: loading them with who looked, making a new one (with the CV and letter as pdf), and pausing, extending
/// and taking back. Also what PAVE suggests and the report.
@Observable
final class SharingModel {
    enum State: Equatable { case loading, ready, notSetUp, unavailable, failed }

    private(set) var state = State.loading
    private(set) var shares: [ProfileShare] = []
    private(set) var applications: [ApplicationDraft] = []
    /// A share being made or changed, so its button waits.
    private(set) var busyShareID: String?
    private(set) var isCreating = false
    var problem: String?

    let service: (any ShareService)?
    let webURL: URL?

    init(service: (any ShareService)?, webURL: URL?) {
        self.service = service
        self.webURL = webURL
        if service == nil { state = .unavailable }
        // Intrekken and Verlengen right from a notification, also when Profiel is not open.
        ShareAlerts.onRevoke = { [weak self] id in await self?.act(on: id) { await $0.revoke($1) } }
        ShareAlerts.onExtend = { [weak self] id in await self?.act(on: id) { await $0.extend($1, by: .week) } }
    }

    private func act(on id: String, _ work: (SharingModel, ProfileShare) async -> Void) async {
        if share(id) == nil { await load() }
        guard let share = share(id) else { return }
        await work(self, share)
    }

    var live: [ProfileShare] { shares.filter { $0.isLive() } }
    var ended: [ProfileShare] { shares.filter { !$0.isLive() } }
    var suggestions: [ShareAdvice.Suggestion] { ShareAdvice.suggestions(shares: shares, applications: applications) }
    var report: ShareAdvice.Report { ShareAdvice.report(shares) }

    func share(_ id: String) -> ProfileShare? { shares.first { $0.id == id } }

    func link(for share: ProfileShare) -> URL? { webURL.map { ShareLinks.share(share.code, base: $0) } }

    func load() async {
        applications = ApplicationStore().all()
        guard let service else { return }
        if shares.isEmpty { state = .loading }
        do {
            shares = try await service.shares()
            state = .ready
            ShareAlerts.update(with: shares)
        } catch ShareError.notSetUp {
            state = .notSetUp
        } catch {
            guard !Task.isCancelled else { return }
            state = shares.isEmpty ? .failed : .ready
        }
    }

    /// Makes the share, then keeps the pdfs of the CV and letter with it. Returns it, or nil when it failed.
    func create(_ draft: ShareDraft, application: ApplicationDraft?, photo: UIImage?) async -> ProfileShare? {
        guard let service, draft.problem == nil else { return nil }
        isCreating = true
        defer { isCreating = false }
        do {
            var share = try await service.create(draft, now: .now)
            if let application, draft.content.cv != nil || draft.content.letter != nil {
                var documents: [String: String] = [:]
                if draft.content.cv != nil, let url = try? ApplicationPDF.file(for: application, document: .cv, photo: application.showsPhoto ? photo : nil),
                   let data = try? Data(contentsOf: url) {
                    documents["cv"] = try await service.upload(pdf: data, kind: "cv", shareID: share.id)
                }
                if draft.content.letter != nil, let url = try? ApplicationPDF.file(for: application, document: .letter, photo: nil),
                   let data = try? Data(contentsOf: url) {
                    documents["letter"] = try await service.upload(pdf: data, kind: "letter", shareID: share.id)
                }
                if !documents.isEmpty {
                    try await service.setDocuments(documents, of: share)
                    share.content.documents = documents
                }
            }
            shares.insert(share, at: 0)
            ShareAlerts.update(with: shares)
            PaveHaptics.success()
            return share
        } catch {
            problem = SharingMessages.actionFailed
            return nil
        }
    }

    func setPaused(_ isPaused: Bool, _ share: ProfileShare) async {
        await change(share) { service in
            try await service.setPaused(isPaused, shareID: share.id)
            return { $0.pausedAt = isPaused ? .now : nil }
        }
    }

    func extend(_ share: ProfileShare, by duration: ShareDuration) async {
        let until = duration.end(from: max(share.expiresAt, .now))
        await change(share) { service in
            try await service.extend(shareID: share.id, until: until)
            return { $0.expiresAt = until }
        }
    }

    func revoke(_ share: ProfileShare) async {
        await change(share) { service in
            try await service.revoke(share)
            return { share in
                share.revokedAt = .now
                share.pausedAt = nil
                share.content = ShareContent(profile: ShareProfile(name: ""))
                share.itemIDs = []
            }
        }
    }

    private func change(_ share: ProfileShare, _ work: (any ShareService) async throws -> (inout ProfileShare) -> Void) async {
        guard let service, busyShareID == nil else { return }
        busyShareID = share.id
        defer { busyShareID = nil }
        do {
            let apply = try await work(service)
            if let index = shares.firstIndex(where: { $0.id == share.id }) { apply(&shares[index]) }
            ShareAlerts.update(with: shares)
            if let changed = self.share(share.id), changed.state() != .active { ShareWatchBridge.clear() }
            PaveHaptics.success()
        } catch {
            problem = SharingMessages.actionFailed
        }
    }
}
