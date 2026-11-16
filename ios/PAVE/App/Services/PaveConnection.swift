import Foundation
import Network
import Observation

/// Whether the device is online, so screens can say so calmly instead of failing after a wait.
@Observable
final class PaveConnection {
    static let shared = PaveConnection()

    private(set) var isOnline = true
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in self?.isOnline = isOnline }
        }
        monitor.start(queue: DispatchQueue(label: "nl.fontys.pave.connection"))
    }
}
