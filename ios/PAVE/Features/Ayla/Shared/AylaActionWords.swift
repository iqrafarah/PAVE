import PAVECore

/// What Ayla says once you said Ja to something that cannot be undone, by what it was.
enum AylaActionWords {
    static func done(_ actions: [AylaAppAction]) -> String {
        let words = actions.filter(\.needsConfirmation).map { action in
            switch action.kind {
            case "deleteChat": AylaMessages.actionDeletedChat
            case "deleteEvidence": AylaMessages.actionDeletedEvidence(action.target ?? "het")
            case "forgetAll": AylaMessages.actionForgotAll
            case "signOut": AylaMessages.actionSignsOut
            default: AylaMessages.actionDone
            }
        }
        return words.isEmpty ? AylaMessages.actionDone : words.joined(separator: " ")
    }
}
