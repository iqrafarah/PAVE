import Foundation
import Observation

/// Whether an Apple Watch can be connected and whether it is, for Instellingen and Ingelogde apparaten.
@Observable
final class WatchConnectionModel {
    private(set) var availability = WatchBridge.Availability.noWatch
    private(set) var connection: WatchConnection?
    private let bridge: WatchBridge

    init(bridge: WatchBridge = .shared) {
        self.bridge = bridge
        bridge.onChange = { [weak self] in
            Task { await self?.refresh() }
        }
    }

    var isConnected: Bool { connection != nil }
    private var isPreview = false

    #if DEBUG
    /// For previews and screenshots: a Watch that is ready to connect, or already connected.
    convenience init(previewAvailability: WatchBridge.Availability, connection: WatchConnection? = nil) {
        self.init(bridge: WatchBridge())
        isPreview = true
        availability = previewAvailability
        self.connection = connection
    }
    #endif

    func refresh() async {
        guard !isPreview else { return }
        availability = bridge.availability
        connection = WatchConnection.current(accountID: await bridge.accountID())
    }

    /// False when nobody is signed in on this iPhone.
    func connect() async -> Bool {
        if isPreview {
            connection = WatchConnection(connectedAt: .now, lastActiveAt: nil)
            return true
        }
        let connected = await bridge.connect()
        await refresh()
        return connected
    }

    func disconnect() async {
        await bridge.disconnect()
        await refresh()
    }
}
