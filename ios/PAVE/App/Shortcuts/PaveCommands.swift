import SwiftUI

/// What the keyboard shortcuts do on the screen that is open. Nil while signed out or locked.
struct PaveActions {
    let newConversation: () -> Void
    let talk: (() -> Void)?
    let searchChats: () -> Void
    let toggleMenu: (() -> Void)?
    let openSettings: () -> Void
}

extension FocusedValues {
    @Entry var paveActions: PaveActions?
}

/// Keyboard shortcuts for iPad and iPhone Duo with a keyboard, in the menu bar and in the list you see when you hold
/// Command. The same keys as ChatGPT and Claude where they have one.
struct PaveCommands: Commands {
    @FocusedValue(\.paveActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nieuw gesprek") { actions?.newConversation() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Instellingen") { actions?.openSettings() }
                .keyboardShortcut(",")
                .disabled(actions == nil)
        }
        CommandGroup(replacing: .sidebar) {
            Button("Menu tonen of verbergen") { actions?.toggleMenu?() }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .disabled(actions?.toggleMenu == nil)
        }
        CommandMenu("Ayla") {
            Button("Praat met Ayla") { actions?.talk?() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(actions?.talk == nil)
            Button("Zoeken in chats") { actions?.searchChats() }
                .keyboardShortcut("k")
                .disabled(actions == nil)
        }
    }
}
