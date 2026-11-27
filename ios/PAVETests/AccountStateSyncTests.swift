import Foundation
import PAVECore
import Testing
@testable import PAVE

/// The phone and the laptop with one account: what changes on one shows on the other, and nothing goes to another account.
@MainActor
struct AccountStateSyncTests {
    private actor Account: AccountStateService {
        var rows: [String: AccountStateRow] = [:]
        var missing = false
        func setMissing() { missing = true }
        func all() async throws -> [AccountStateRow] {
            if missing { throw AccountStateServiceError.notSetUp }
            return Array(rows.values)
        }
        func save(_ new: [AccountStateRow]) async throws { for row in new { rows[row.id] = row } }
        func value(_ id: String) -> String? { rows[id].map { String(decoding: $0.value, as: UTF8.self) } }
    }

    private func device(_ account: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "device-\(UUID().uuidString)")!
        PaveAccount.set(account, in: defaults)
        return defaults
    }

    @Test func whatIsSeenAndChosenOnThePhoneIsThereOnTheLaptop() async {
        let account = Account()
        let phone = device("ravi"), laptop = device("ravi")
        var clock = Date(timeIntervalSince1970: 1_000)
        let phoneSync = AccountStateSync(service: account, defaults: phone) { clock }
        let laptopSync = AccountStateSync(service: account, defaults: laptop) { clock }

        phone.set(["inv-1"], forKey: PaveAccount.key("fair.seenInvitations", in: phone))
        phone.set(["e1": "applied"], forKey: PaveAccount.key("aylaPlanEditDecisions", in: phone))
        phone.set(["mail-1"], forKey: PaveAccount.key("emailPinnedThreads", in: phone))
        await phoneSync.run()
        #expect(await account.value("seen/fairInvitations") == #"["inv-1"]"#)

        clock = Date(timeIntervalSince1970: 2_000)
        laptop.set(["inv-2"], forKey: PaveAccount.key("fair.seenInvitations", in: laptop))
        let pulled = await laptopSync.run()
        #expect(pulled)
        #expect(laptop.stringArray(forKey: PaveAccount.key("fair.seenInvitations", in: laptop)) == ["inv-2", "inv-1"])
        #expect(laptop.dictionary(forKey: PaveAccount.key("aylaPlanEditDecisions", in: laptop)) as? [String: String] == ["e1": "applied"])
        #expect(laptop.stringArray(forKey: PaveAccount.key("emailPinnedThreads", in: laptop)) == ["mail-1"])

        // Unpinned on the laptop later: the phone follows, the newest wins.
        clock = Date(timeIntervalSince1970: 3_000)
        laptop.set([String](), forKey: PaveAccount.key("emailPinnedThreads", in: laptop))
        await laptopSync.run()
        await phoneSync.run()
        #expect(phone.stringArray(forKey: PaveAccount.key("emailPinnedThreads", in: phone)) == [])
        #expect(phone.stringArray(forKey: PaveAccount.key("fair.seenInvitations", in: phone)) == ["inv-1", "inv-2"])
    }

    @Test func theFairDayGoesAlong() async throws {
        let account = Account()
        let phone = device("ravi"), laptop = device("ravi")
        let entries: [[String: Any]] = [["date": 812_000_000.0, "event": ["scanned": ["employer": "Kade", "slug": "kade"]]]]
        phone.set(try JSONSerialization.data(withJSONObject: entries), forKey: PaveAccount.key("fair.day", in: phone))
        await AccountStateSync(service: account, defaults: phone).run()
        await AccountStateSync(service: account, defaults: laptop).run()
        let data = try #require(laptop.data(forKey: PaveAccount.key("fair.day", in: laptop)))
        let back = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(back.count == 1)
    }

    @Test func signedOutNothingGoesAndWithoutTheTableNothingBreaks() async {
        let account = Account()
        let phone = device("ravi")
        phone.set(["inv-1"], forKey: PaveAccount.key("fair.seenInvitations", in: phone))
        PaveAccount.set(nil, in: phone)
        #expect(await AccountStateSync(service: account, defaults: phone).run() == false)
        #expect(await account.rows.isEmpty)

        await account.setMissing()
        PaveAccount.set("ravi", in: phone)
        let sync = AccountStateSync(service: account, defaults: phone)
        #expect(await sync.run() == false)
        #expect(sync.isAvailable == false)
        #expect(phone.stringArray(forKey: PaveAccount.key("fair.seenInvitations", in: phone)) == ["inv-1"])
    }
}
