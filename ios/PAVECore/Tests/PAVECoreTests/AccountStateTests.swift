import Foundation
import Testing
@testable import PAVECore

struct AccountStateTests {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    @Test func theNewestCopyWins() {
        #expect(AccountStateMerge.newest.merge(local: "laptop", localAt: earlier, remote: "telefoon", remoteAt: later) as? String == "telefoon")
        #expect(AccountStateMerge.newest.merge(local: "telefoon", localAt: later, remote: "laptop", remoteAt: earlier) as? String == "telefoon")
        #expect(AccountStateMerge.newest.merge(local: nil, localAt: nil, remote: "account", remoteAt: earlier) as? String == "account")
        #expect(AccountStateMerge.newest.merge(local: "hier", localAt: earlier, remote: nil, remoteAt: nil) as? String == "hier")
    }

    @Test func whatWasSeenOnOneDeviceStaysSeenOnTheOther() {
        let merged = AccountStateMerge.unionOfStrings.merge(local: ["a", "b"], localAt: later, remote: ["b", "c"], remoteAt: earlier) as? [String]
        #expect(merged == ["a", "b", "c"])
    }

    @Test func choicesPerProposalComeTogether() {
        let merged = AccountStateMerge.unionOfKeys.merge(local: ["e1": "applied", "e2": "declined"], localAt: earlier, remote: ["e2": "applied", "e3": "declined"], remoteAt: later) as? [String: String]
        #expect(merged == ["e1": "applied", "e2": "applied", "e3": "declined"])
    }

    @Test func theLatestMomentWins() {
        let merged = AccountStateMerge.latestDate.merge(local: "2026-11-27T10:00:00Z", localAt: later, remote: "2026-11-27T12:00:00Z", remoteAt: earlier) as? String
        #expect(merged == "2026-11-27T12:00:00Z")
    }

    @Test func theFairDayOfBothDevicesIsOneDay() {
        let phone: [[String: Any]] = [["date": 100.0, "event": ["scanned": ["employer": "Kade"]]]]
        let laptop: [[String: Any]] = [["date": 50.0, "event": ["applied": ["employer": "Jumbo"]]], ["date": 100.0, "event": ["scanned": ["employer": "Kade"]]]]
        let merged = AccountStateMerge.unionByDate.merge(local: phone, localAt: later, remote: laptop, remoteAt: earlier) as? [[String: Any]]
        #expect(merged?.count == 2)
        #expect(merged?.first?["date"] as? Double == 50)
    }

    @Test func rowsGoToTheTableAndComeBack() throws {
        let row = AccountStateRow(scope: "seen", key: "fairInvitations", value: Data(#"["a","b"]"#.utf8), updatedAt: later)
        let body = try SupabaseAccountStateService.body([row])
        let sent = try #require(try JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        #expect(sent.first?["scope"] as? String == "seen")
        #expect(sent.first?["value"] as? [String] == ["a", "b"])
        let back = SupabaseAccountStateService.decode(Data(#"[{"scope":"seen","key":"fairInvitations","value":["a","b"],"updated_at":"1970-01-01T00:33:20.000Z"}]"#.utf8))
        #expect(back.first?.updatedAt == later)
        #expect(try JSONSerialization.jsonObject(with: back.first!.value) as? [String] == ["a", "b"])
    }
}
