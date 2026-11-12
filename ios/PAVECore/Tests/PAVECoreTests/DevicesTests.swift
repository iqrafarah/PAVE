import Foundation
import Testing
@testable import PAVECore

struct DevicesTests {
    @Test func namesTheAppAndCommonBrowsers() {
        let cases: [(String, SignedInDevice.Kind, SignedInDevice.Client)] = [
            ("PAVE-iOS/0.1 (iPhone; iOS 26.1)", .iPhone, .paveApp),
            ("PAVE-iOS/0.1 (iPad; iOS 26.1)", .iPad, .paveApp),
            ("PAVE/1 CFNetwork/3826.400.120 Darwin/25.1.0", .unknown, .paveApp),
            ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Safari/605.1.15", .mac, .browser("Safari")),
            ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0", .windows, .browser("Edge")),
            ("Mozilla/5.0 (iPhone; CPU iPhone OS 26_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/142.0 Mobile/15E148 Safari/604.1", .iPhone, .browser("Chrome")),
            ("Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0 Mobile Safari/537.36", .android, .browser("Chrome")),
            ("Mozilla/5.0 (X11; Linux x86_64; rv:144.0) Gecko/20100101 Firefox/144.0", .linux, .browser("Firefox")),
            ("", .unknown, .unknown),
        ]
        for (agent, kind, client) in cases {
            let described = SignedInDevice.describe(userAgent: agent)
            #expect(described.0 == kind, "\(agent)")
            #expect(described.1 == client, "\(agent)")
        }
        #expect(SignedInDevice.appUserAgent(version: "0.1", model: "iPhone", systemVersion: "26.1") == "PAVE-iOS/0.1 (iPhone; iOS 26.1)")
    }

    @Test func readsTheSessionsOfTheAccount() throws {
        let json = Data("""
        [{"id":"a","signed_in_at":"2026-11-10T08:00:00Z","last_active_at":"2026-11-12T10:30:00Z","user_agent":"PAVE-iOS/0.1 (iPhone; iOS 26.1)","is_current":true},
         {"id":"b","signed_in_at":"2026-11-01T08:00:00Z","last_active_at":"bad","user_agent":null,"is_current":false}]
        """.utf8)
        let devices = try JSONDecoder().decode([SessionRow].self, from: json).compactMap(\.device)
        #expect(devices.count == 1)
        #expect(devices.first?.isCurrent == true)
        #expect(devices.first?.kind == .iPhone)
        #expect(devices.first?.lastActiveAt == Date(timeIntervalSince1970: 1_794_479_400))
    }

    @Test func aMissingFunctionMeansNotSetUp() {
        #expect(SupabaseDevicesService.error(status: 404, body: Data(#"{"code":"PGRST202"}"#.utf8)) == .notSetUp)
        #expect(SupabaseDevicesService.error(status: 401, body: Data()) == .notSignedIn)
        #expect(SupabaseDevicesService.error(status: 400, body: Data(#"{"code":"42501"}"#.utf8)) == .notAllowed)
        #expect(SupabaseDevicesService.error(status: 500, body: Data()) == .unavailable)
    }
}
