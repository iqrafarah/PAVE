import Foundation
import Testing
@testable import PAVE

struct WatchConnectionTests {
    @Test func belongsToOneAccountUntilDisconnected() throws {
        let defaults = try #require(UserDefaults(suiteName: "WatchConnectionTests"))
        defaults.removePersistentDomain(forName: "WatchConnectionTests")
        #expect(WatchConnection.current(accountID: "a", defaults: defaults) == nil)

        let connectedAt = Date(timeIntervalSince1970: 1_794_479_400)
        WatchConnection.connect(accountID: "a", now: connectedAt, defaults: defaults)
        #expect(WatchConnection.current(accountID: "a", defaults: defaults) == WatchConnection(connectedAt: connectedAt, lastActiveAt: nil))
        #expect(WatchConnection.current(accountID: "b", defaults: defaults) == nil)
        #expect(WatchConnection.current(accountID: nil, defaults: defaults) == nil)

        let active = connectedAt.addingTimeInterval(600)
        WatchConnection.markActive(now: active, defaults: defaults)
        #expect(WatchConnection.current(accountID: "a", defaults: defaults)?.lastActiveAt == active)

        WatchConnection.disconnect(defaults: defaults)
        #expect(WatchConnection.current(accountID: "a", defaults: defaults) == nil)
        WatchConnection.markActive(defaults: defaults)
        #expect(defaults.object(forKey: "watchLastActiveAt") == nil)
    }
}
