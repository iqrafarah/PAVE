import Foundation
import Observation
import PAVECore

/// The devices the account is signed in on, for Instellingen. Signing one out removes it from the list straight away and
/// puts it back when that fails.
@Observable
final class SignedInDevicesModel {
    enum State: Equatable {
        case idle
        case loading
        case ready
        /// The database functions are not there yet (migration 20261112150000).
        case notSetUp
        /// The demo login has no sessions.
        case unavailable
        case failed(DevicesError)
    }

    private(set) var state = State.idle
    private(set) var devices: [SignedInDevice] = []
    /// The device that is being signed out, or every other one (`allOthers`).
    private(set) var signingOut: String?
    var problem: String?

    nonisolated static let allOthers = "allOthers"

    private let service: (any DevicesService)?

    init(service: (any DevicesService)?) {
        self.service = service
        if service == nil { state = .unavailable }
    }

    var current: SignedInDevice? { devices.first(where: \.isCurrent) }
    var others: [SignedInDevice] { devices.filter { !$0.isCurrent } }

    func load() async {
        guard let service else { return }
        if devices.isEmpty { state = .loading }
        do {
            devices = try await service.devices()
            state = .ready
        } catch {
            let error = DevicesError(error)
            if error == .notSetUp {
                state = .notSetUp
            } else if devices.isEmpty {
                state = .failed(error)
            } else {
                problem = DevicesMessages.message(for: error)
            }
        }
    }

    func signOut(_ device: SignedInDevice) async {
        guard let service, signingOut == nil else { return }
        signingOut = device.id
        defer { signingOut = nil }
        problem = nil
        do {
            try await service.signOut(device)
            devices.removeAll { $0.id == device.id }
            PaveHaptics.success()
        } catch {
            problem = DevicesMessages.message(for: DevicesError(error))
            PaveHaptics.error()
        }
    }

    func signOutOthers() async {
        guard let service, signingOut == nil else { return }
        signingOut = Self.allOthers
        defer { signingOut = nil }
        problem = nil
        do {
            try await service.signOutOtherDevices()
            devices.removeAll { !$0.isCurrent }
            PaveHaptics.success()
        } catch {
            problem = DevicesMessages.message(for: DevicesError(error))
            PaveHaptics.error()
        }
    }
}
