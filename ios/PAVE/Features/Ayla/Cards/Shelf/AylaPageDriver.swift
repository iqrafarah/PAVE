import SwiftUI

/// How Ayla moves through a page that is open over the chat when you ask her to ("open weergave", "open de map
/// Stages", "ga terug"): the page watches this and goes there itself, so you see it happen.
@Observable
final class AylaPageDriver {
    var settingsPage: SettingsScreen.SettingsDestination?
    var vaultFolderID: String?
    /// Goes up once for every step back.
    var backSteps = 0
}
