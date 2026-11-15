import ActivityKit
import Foundation

/// A spoken conversation with Ayla on the Lock Screen and in the Dynamic Island, so you can keep talking with the
/// phone in your pocket and still see what Ayla is doing. Only her status shows, never what is said: the Lock Screen
/// can be seen by others.
nonisolated struct AylaVoiceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Status: String, Codable, Hashable {
            case listening
            case thinking
            case speaking
            case muted
            case paused
        }

        var status: Status

        var title: String {
            switch status {
            case .listening: "Ayla luistert"
            case .thinking: "Ayla denkt na"
            case .speaking: "Ayla praat"
            case .muted: "Je microfoon staat uit"
            case .paused: "Gepauzeerd"
            }
        }

        var hint: String {
            switch status {
            case .listening: "Praat gewoon verder, of knik ja of schud nee."
            case .thinking: "Even geduld."
            case .speaking: "Druk op je AirPods om haar te onderbreken."
            case .muted: "Druk op je AirPods om weer te praten."
            case .paused: "Doe je AirPods in om verder te gaan."
            }
        }

        /// Shorter, for the Dynamic Island next to the camera.
        var short: String {
            switch status {
            case .listening: "Luistert"
            case .thinking: "Denkt na"
            case .speaking: "Praat"
            case .muted: "Stil"
            case .paused: "Pauze"
            }
        }
    }
}
