import AppIntents

/// What Siri, Spotlight, Shortcuts and the Action button offer for PAVE, without setting anything up.
struct PaveAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TalkToAylaIntent(),
            phrases: [
                "Praat met Ayla in \(.applicationName)",
                "Start een gesprek met Ayla in \(.applicationName)",
                "\(.applicationName) praat met Ayla",
            ],
            shortTitle: "Praat met Ayla",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: AskAylaIntent(),
            phrases: [
                "Vraag Ayla iets in \(.applicationName)",
                "Stel Ayla een vraag in \(.applicationName)",
                "\(.applicationName) vraag Ayla",
            ],
            shortTitle: "Vraag Ayla",
            systemImageName: "questionmark.bubble"
        )
        AppShortcut(
            intent: NewAylaConversationIntent(),
            phrases: [
                "Nieuw gesprek in \(.applicationName)",
            ],
            shortTitle: "Nieuw gesprek",
            systemImageName: "bubble.left.fill"
        )
        AppShortcut(
            intent: ShowSharesIntent(),
            phrases: [
                "Wie kan mijn gegevens zien in \(.applicationName)",
                "Wat deel ik in \(.applicationName)",
            ],
            shortTitle: "Wat deel ik?",
            systemImageName: "person.2"
        )
        AppShortcut(
            intent: StopSharingIntent(),
            phrases: [
                "Stop met delen in \(.applicationName)",
                "Trek mijn gegevens in met \(.applicationName)",
            ],
            shortTitle: "Stop met delen",
            systemImageName: "hand.raised"
        )
    }
}
