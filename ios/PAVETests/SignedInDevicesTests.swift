import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct SignedInDevicesTests {
    private actor FakeDevices: DevicesService {
        var list: [SignedInDevice]
        var signedOut: [String] = []
        var missingFunctions = false

        init(_ list: [SignedInDevice]) { self.list = list }
        func dropFunctions() { missingFunctions = true }

        func devices() async throws -> [SignedInDevice] {
            if missingFunctions { throw DevicesError.notSetUp }
            return list
        }

        func signOut(_ device: SignedInDevice) async throws {
            signedOut.append(device.id)
            list.removeAll { $0.id == device.id }
        }

        func signOutOtherDevices() async throws {
            signedOut.append(SignedInDevicesModel.allOthers)
            list.removeAll { !$0.isCurrent }
        }
    }

    private static func device(_ id: String, current: Bool = false) -> SignedInDevice {
        SignedInDevice(id: id, kind: .mac, client: .browser("Safari"), signedInAt: .now, lastActiveAt: .now, isCurrent: current)
    }

    @Test func showsThisDeviceApartAndSignsOthersOut() async {
        let service = FakeDevices([Self.device("web"), Self.device("phone", current: true), Self.device("ipad")])
        let model = SignedInDevicesModel(service: service)
        await model.load()
        #expect(model.state == .ready)
        #expect(model.current?.id == "phone")
        #expect(model.others.map(\.id) == ["web", "ipad"])

        await model.signOut(model.others[0])
        #expect(model.others.map(\.id) == ["ipad"])
        await model.signOutOthers()
        #expect(model.others.isEmpty)
        #expect(model.current?.id == "phone")
        #expect(await service.signedOut == ["web", SignedInDevicesModel.allOthers])
    }

    @Test func withoutTheMigrationItSaysSoAndTheDemoHasNoDevices() async {
        let service = FakeDevices([])
        await service.dropFunctions()
        let model = SignedInDevicesModel(service: service)
        await model.load()
        #expect(model.state == .notSetUp)
        #expect(SignedInDevicesModel(service: nil).state == .unavailable)
    }

    @Test func namesAndTimes() {
        let now = Date(timeIntervalSince1970: 1_794_479_400)
        let web = SignedInDevice(id: "w", kind: .mac, client: .browser("Safari"), signedInAt: now.addingTimeInterval(-86_400 * 2), lastActiveAt: now.addingTimeInterval(-7200), isCurrent: false)
        #expect(DevicesMessages.name(of: web) == "Safari op Mac")
        #expect(DevicesMessages.activity(of: web, now: now) == "Actief 2 uur geleden")
        #expect(DevicesMessages.signedIn(of: web) == "Ingelogd op 10 nov")
        let app = SignedInDevice(id: "a", kind: .unknown, client: .paveApp, signedInAt: now, lastActiveAt: now, isCurrent: true)
        #expect(DevicesMessages.name(of: app) == "PAVE-app")
        #expect(DevicesMessages.activity(of: app, now: now) == "Nu actief")
    }
}
