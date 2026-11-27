import PAVECore

/// The words for what Ayla does in the app: the line you follow while she does it, and what she says once you said
/// Ja to something that asks first.
enum AylaActionWords {
    /// "Donker aanzetten", "Map Stages openen": one action as a step.
    static func doing(_ action: AylaAppAction) -> String {
        let target = action.target ?? ""
        let value = action.value ?? ""
        let onOff = action.isOn == false ? "uitzetten" : "aanzetten"
        switch action.kind {
        case "openSettingsPage": return "Instellingen openen"
        case "openMemory": return "Openen wat Ayla onthoudt"
        case "openSavedVacancies": return "Bewaarde vacatures openen"
        case "openFolder": return "Map \(target) openen"
        case "back": return "Een stap terug"
        case "close": return "Sluiten"
        case "newChat": return "Nieuwe chat starten"
        case "openChat": return "Chat over \(target) openen"
        case "renameChat": return "Chat \(value) noemen"
        case "pinChat": return action.isOn == false ? "Chat losmaken" : "Chat vastzetten"
        case "archiveChat": return "Chat archiveren"
        case "setChatExpiry": return "Verval van deze chat instellen"
        case "setTheme": return "Thema veranderen"
        case "setTextSize": return "Tekstgrootte aanpassen"
        case "setDisplayMode":
            switch value.lowercased() {
            case "dark": return "Donker aanzetten"
            case "light": return "Licht aanzetten"
            default: return "Licht of donker laten volgen"
            }
        case "setVaultLayout": return value.lowercased() == "list" ? "Kluis als lijst tonen" : "Kluis als raster tonen"
        case "setVoiceText": return "Tekst bij praten \(onOff)"
        case "setChatsInSearch": return "Chats in iPhone-zoeken \(onOff)"
        case "setAnimations": return "Animaties \(onOff)"
        case "setMemory": return "Onthouden \(onOff)"
        case "createFolder": return "Map \(value) maken"
        case "moveToFolder": return "\(target) in de map \(value) zetten"
        case "archiveEvidence": return "\(target) archiveren"
        case "allowAyla": return action.isOn == false ? "Toegang tot \(target) uitzetten" : "Toegang tot \(target) aanzetten"
        case "requestVerification": return "Formulier openen om \(target) te laten bevestigen"
        case "openVacancy": return "Vacature openen"
        case "saveVacancy": return "Vacature bewaren"
        case "deleteChat": return "Chat verwijderen"
        case "deleteEvidence": return "\(target) verwijderen"
        case "deletePlan": return "Plan \(target) verwijderen"
        case "signOut": return "Uitloggen"
        case "forgetAll": return "Alles vergeten"
        default: return "Iets in de app doen"
        }
    }

    static func done(_ actions: [AylaAppAction]) -> String {
        let words = actions.filter(\.needsConfirmation).map { action in
            switch action.kind {
            case "deleteChat": AylaMessages.actionDeletedChat
            case "deleteEvidence": AylaMessages.actionDeletedEvidence(action.target ?? "het")
            case "deletePlan": AylaMessages.actionDeletedPlan(action.target ?? "")
            case "forgetAll": AylaMessages.actionForgotAll
            case "signOut": AylaMessages.actionSignsOut
            case "allowAyla": AylaMessages.actionAllowed(action.target ?? "het")
            default: AylaMessages.actionDone
            }
        }
        return words.isEmpty ? AylaMessages.actionDone : words.joined(separator: " ")
    }
}
