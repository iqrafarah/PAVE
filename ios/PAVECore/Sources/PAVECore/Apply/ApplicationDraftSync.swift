import Foundation

/// An application as the account keeps it, so a draft started on one device goes on on another. A deleted one stays
/// as a row without a draft, so the other devices remove it too.
public struct RemoteApplicationDraft: Equatable, Sendable {
    public let id: String
    public let updatedAt: Date
    public let deletedAt: Date?
    public let draft: ApplicationDraft?

    public init(id: String, updatedAt: Date, deletedAt: Date? = nil, draft: ApplicationDraft?) {
        self.id = id
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.draft = draft
    }
}

public protocol ApplicationDraftService: Sendable {
    func all() async throws -> [RemoteApplicationDraft]
    func save(_ draft: ApplicationDraft) async throws
    func delete(id: String, at date: Date) async throws
}

/// What has to move between this device and the account. The one changed last wins, a whole application at a time;
/// deleting counts as a change.
public enum ApplicationDraftSync {
    public struct Plan: Equatable, Sendable {
        /// Newer in the account: write on this device.
        public var download: [ApplicationDraft] = []
        /// Deleted on another device: remove here.
        public var removeLocally: [String] = []
        /// Newer on this device: send to the account.
        public var upload: [ApplicationDraft] = []
        /// Deleted here: mark as deleted in the account.
        public var deleteRemotely: [String: Date] = [:]
        /// Deletions of this device that no longer need remembering.
        public var settled: [String] = []

        public var isEmpty: Bool { download.isEmpty && removeLocally.isEmpty && upload.isEmpty && deleteRemotely.isEmpty }
    }

    /// Clocks and the stored precision differ a little; within this, two copies count as the same.
    static let tolerance: TimeInterval = 1

    public static func plan(local: [ApplicationDraft], deletedLocally: [String: Date], remote: [RemoteApplicationDraft]) -> Plan {
        var plan = Plan()
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for (id, deletedAt) in deletedLocally where localByID[id] == nil {
            guard let row = remoteByID[id], row.deletedAt == nil, let draft = row.draft else {
                plan.settled.append(id)
                continue
            }
            if row.updatedAt > deletedAt.addingTimeInterval(tolerance) {
                // Worked on elsewhere after it was deleted here: it comes back.
                plan.download.append(draft)
                plan.settled.append(id)
            } else {
                plan.deleteRemotely[id] = deletedAt
            }
        }

        for draft in local {
            guard let row = remoteByID[draft.id] else {
                plan.upload.append(draft)
                continue
            }
            if let deletedAt = row.deletedAt {
                if draft.updatedAt > deletedAt.addingTimeInterval(tolerance) { plan.upload.append(draft) } else { plan.removeLocally.append(draft.id) }
            } else if draft.updatedAt > row.updatedAt.addingTimeInterval(tolerance) {
                plan.upload.append(draft)
            } else if row.updatedAt > draft.updatedAt.addingTimeInterval(tolerance), let newer = row.draft {
                plan.download.append(newer)
            }
        }

        for row in remote where row.deletedAt == nil && localByID[row.id] == nil && deletedLocally[row.id] == nil {
            if let draft = row.draft { plan.download.append(draft) }
        }
        plan.settled.sort()
        plan.removeLocally.sort()
        plan.download.sort { $0.id < $1.id }
        plan.upload.sort { $0.id < $1.id }
        return plan
    }
}
