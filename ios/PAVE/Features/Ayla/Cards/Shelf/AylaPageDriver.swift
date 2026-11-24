import PAVECore
import SwiftUI

/// How Ayla moves through a page that is open over the chat when you ask her to ("open weergave", "open de map
/// Stages", "ga terug"): the page watches this and goes there itself, so you see it happen.
@Observable
final class AylaPageDriver {
    var settingsPage: SettingsScreen.SettingsDestination?
    var vaultFolderID: String?
    /// The vacancy open in the vacancies panel.
    var vacancy: Vacancy?
    /// Goes up once for every step back.
    var backSteps = 0
    /// How many pages deep Instellingen and the vault are, so a step back at the start closes the page instead.
    var settingsDepth = 0
    var vaultDepth = 0
}
