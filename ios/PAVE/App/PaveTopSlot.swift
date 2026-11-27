import Observation
import SwiftUI

/// The top of the screen holds one floating message at a time: a melding, "Klaar met deze stap?", Ayla's answer over the
/// chat, the way back to an application, or the plan opening for a moment around the camera. Each one says here when it
/// shows; the others wait or step aside, so they never lie on top of each other.
@MainActor @Observable
final class PaveTopSlot {
    static let shared = PaveTopSlot()

    /// A melding or "Klaar met deze stap?" is on screen (MainView).
    var messageShows = false
    /// Ayla's answer floats over the chat, or a page lies over it (AylaChatScreen).
    var chatHoldsTop = false

    /// Something already floats at the top.
    var isTaken: Bool { messageShows || chatHoldsTop }
}

extension View {
    /// The chat tells whether it holds the top of the screen, and lets it go when it leaves.
    func reportsTop(holding holds: Bool) -> some View {
        onChange(of: holds, initial: true) { _, holds in PaveTopSlot.shared.chatHoldsTop = holds }
            .onDisappear { PaveTopSlot.shared.chatHoldsTop = false }
    }
}
