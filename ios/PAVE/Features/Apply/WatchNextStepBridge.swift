import Foundation
import PAVECore
import WatchConnectivity

/// Sends the next step with your applications to the Apple Watch, for a glance at the wrist: the kind, the company and
/// when. Sent again only when it changes; nothing goes when there is no Watch with PAVE on it.
@MainActor
enum WatchNextStepBridge {
    static let key = "nextStep"
    private static var drafts: [ApplicationDraft]?
    private static var fair: [FairApplication] = []
    private static var lastSent: NextStep??

    static func update(drafts: [ApplicationDraft]) {
        self.drafts = drafts
        publish()
    }

    static func update(fair: [FairApplication]) {
        self.fair = fair
        if drafts == nil { drafts = ApplicationStore().all() }
        publish()
    }

    /// Signing out: the Watch forgets the next step of this account.
    static func clear() {
        drafts = nil
        fair = []
        lastSent = nil
        guard ShareWatchBridge.isAvailable else { return }
        WCSession.default.transferUserInfo([key: ["clear": true]])
    }

    private static func publish() {
        guard ShareWatchBridge.isAvailable, let drafts else { return }
        let step = NextStep.pick(drafts: drafts, fair: fair) { slug in
            FairDay.employerName(slug: slug) ?? slug.replacingOccurrences(of: "-", with: " ").capitalized
        }
        guard lastSent != .some(step) else { return }
        lastSent = .some(step)
        if let step, let data = try? JSONEncoder().encode(step) {
            WCSession.default.transferUserInfo([key: ["step": data]])
        } else {
            WCSession.default.transferUserInfo([key: ["clear": true]])
        }
    }
}
