import PAVECore
import SwiftUI

extension EnvironmentValues {
    /// Opens a part of PAVE that Ayla points to, such as the vault or one item in it (the reply's navigation).
    @Entry var openFromAyla: ((AylaReply.Navigation) -> Void)?
    /// "Deel mijn cv met Kade", "stop met delen met Kade": Profiel opens with it filled in; you confirm there.
    @Entry var shareFromAyla: ((AylaShareCommand) -> Void)?
    /// Starts a conversation with Ayla about one item from the vault.
    @Entry var askAylaAbout: ((VaultItem) -> Void)?
}
