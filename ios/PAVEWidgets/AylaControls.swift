import AppIntents
import SwiftUI
import WidgetKit

/// A button in Control Center, on the Lock Screen or under the Action button that starts talking with Ayla.
struct TalkToAylaControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "nl.fontys.pave.talk-to-ayla") {
            ControlWidgetButton(action: TalkToAylaIntent()) {
                Label("Praat met Ayla", systemImage: "waveform")
            }
        }
        .displayName("Praat met Ayla")
        .description("Open PAVE en begin meteen een gesprek met Ayla.")
    }
}

/// A button in Control Center or on the Lock Screen that opens a new chat with Ayla.
struct NewConversationControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "nl.fontys.pave.new-conversation") {
            ControlWidgetButton(action: NewAylaConversationIntent()) {
                Label("Nieuw gesprek", systemImage: "bubble.left.fill")
            }
        }
        .displayName("Nieuw gesprek met Ayla")
        .description("Open PAVE met een nieuw gesprek met Ayla.")
    }
}

/// A button in Control Center or on the Lock Screen that stops sharing: PAVE opens and asks whether to pause or take back
/// everything, after your PIN and with Face ID.
struct StopSharingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "nl.fontys.pave.stop-sharing") {
            ControlWidgetButton(action: StopSharingIntent()) {
                Label("Stop met delen", systemImage: "hand.raised")
            }
        }
        .displayName("Stop met delen")
        .description("Open PAVE en pauzeer of trek alles in wat je deelt.")
    }
}
