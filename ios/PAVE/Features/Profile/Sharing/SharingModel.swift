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
    /// Saved profiles; nil until loaded or while the table is not there yet.
    private(set) var profiles: [SavedProfile]?
    /// Applications left at the fair; nil until loaded or while the table is not there yet.
    private(set) var fairApplications: [FairApplication]?
    /// A share being made or changed, so its button waits.
    private(set) var busyShareID: String?
    private(set) var isCreating = false
    var problem: String?
    /// Siri or Control Center asked to stop sharing; Profiel asks how.
    var asksToStopAll = false
    /// A share notification was tapped: Profiel opens on that share's page.
    var shareToOpen: String?
    /// Opened from an invitation at the fair: Profiel goes on to Mijn beursdag.
    var showsFairDay = false
    /// Ayla was asked to share or to stop; Profiel opens it.
    var request: AylaShareCommand?
    /// A share to ask about taking back, when its detail opens.
    var asksToRevoke: String?

    func request(_ command: AylaShareCommand) { request = command }

    /// The live share with this organisation or person, for "stop met delen met Kade".
    func live(named name: String) -> ProfileShare? {
        let wanted = name.lowercased()
        return live.first { share in
            [share.recipientOrganisation, share.recipientName, share.title].compactMap { $0?.lowercased() }.contains { $0.contains(wanted) || wanted.contains($0) }
        }
    }

    let service: (any ShareService)?
    let webURL: URL?

    init(service: (any ShareService)?, webURL: URL?) {
        self.service = service
        self.webURL = webURL
        if service == nil { state = .unavailable }
        // Intrekken and Verlengen right from a notification, also when Profiel is not open.
        ShareAlerts.onRevoke = { [weak self] id in await self?.act(on: id) { await $0.revoke($1) } }
        ShareAlerts.onExtend = { [weak self] id in await self?.act(on: id) { await $0.extend($1, by: .week) } }
        ShareAlerts.onOpen = { [weak self] id in
            self?.shareToOpen = id
            PaveLinkInbox.send(.shares)
        }
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

    /// The applications as they are on the device now, for a composer opened from the studio.
    func reloadApplications() { applications = ApplicationStore().all() }

    /// What was shared for this application, newest first. A share that was taken back keeps nothing, not even which
    /// application it was for, so it drops out here.
    func shares(forVacancy vacancyID: String) -> [ProfileShare] {
        shares.filter { $0.content.vacancyID == vacancyID }.sorted { $0.createdAt > $1.createdAt }
    }

    func load() async {
        applications = ApplicationStore().all()
        guard let service else { return }
        profiles = try? await service.savedProfiles()
        await loadFairApplications()
        if shares.isEmpty { state = .loading }
        do {
            shares = try await service.shares()
            state = .ready
            ShareAlerts.update(with: shares)
            ApplicationWidgetSnapshot.update(shares: shares)
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
            // The link exists from here on: a pdf that does not make it never hides it, or a retry would make a second one.
            do {
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
            } catch {
                problem = SharingMessages.documentsFailed
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

    /// Pauses or takes back every live share, after Face ID where there is one.
    func stopAll(revoking: Bool) async {
        let authenticator = LocalBiometricAuthenticator()
        if authenticator.kind != nil, !(await authenticator.authenticate(reason: revoking ? SharingMessages.revokeAllReason : SharingMessages.pauseAllReason)) { return }
        for share in live where revoking || share.state() == .active {
            if revoking { await revoke(share) } else { await setPaused(true, share) }
        }
        ShareWatchBridge.clear()
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

    /// Reads your fair applications again; a new invitation is announced once.
    func loadFairApplications() async {
        guard let service, let found = try? await service.fairApplications() else { return }
        fairApplications = found
        FairAlerts.announce(found)
    }

    /// Leaves your card with a vacancy; nil when it could not.
    func apply(_ card: FairApplicationCard, employer: FairEmployer, vacancy: Vacancy) async -> FairApplication? {
        guard let service else { return nil }
        do {
            let kept = try await service.apply(card, employer: employer.slug, vacancy: vacancy)
            var list = fairApplications ?? []
            list.removeAll { $0.id == kept.id }
            list.insert(kept, at: 0)
            fairApplications = list
            return kept
        } catch {
            problem = SharingMessages.applyFailed
            return nil
        }
    }

    func answer(_ application: FairApplication, accepted: Bool) async {
        guard let service else { return }
        do {
            try await service.answer(application.id, accepted: accepted)
            await loadFairApplications()
        } catch {
            problem = SharingMessages.loadFailed
        }
    }

    /// Keeps a new or changed profile; false when it could not be kept.
    func save(_ profile: SavedProfile) async -> Bool {
        guard let service else { return false }
        do {
            let kept = try await service.save(profile)
            var list = profiles ?? []
            list.removeAll { $0.id == kept.id }
            list.insert(kept, at: 0)
            profiles = list
            return true
        } catch {
            problem = SharingMessages.profileSaveFailed
            return false
        }
    }

    /// False when it could not be deleted; the profile stays.
    @discardableResult
    func delete(_ profile: SavedProfile) async -> Bool {
        guard let service else { return false }
        do {
            try await service.delete(profileID: profile.id)
            profiles?.removeAll { $0.id == profile.id }
            return true
        } catch {
            problem = SharingMessages.loadFailed
            return false
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
