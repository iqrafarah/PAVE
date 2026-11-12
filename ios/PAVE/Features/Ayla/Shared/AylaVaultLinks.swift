import PAVECore
import SwiftUI

extension EnvironmentValues {
    /// Opens a part of PAVE that Ayla points to, such as the vault or one item in it (the reply's navigation).
    @Entry var openFromAyla: ((AylaReply.Navigation) -> Void)?
    /// Starts a conversation with Ayla about one item from the vault.
    @Entry var askAylaAbout: ((VaultItem) -> Void)?
}
