import Foundation

/// Who is signed in on this iPhone, for what PAVE keeps on the device itself: each account has its own copy, and
/// signing out puts every copy out of sight. What is in the account itself lives in Supabase.
enum PaveAccount {
    private static let key = "pave.account"

    /// The account signed in now; nil while signed out.
    static func current(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key)
    }

    static func set(_ accountID: String?, in defaults: UserDefaults = .standard) {
        if let accountID, !accountID.isEmpty { defaults.set(accountID, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    /// A key of this account's own: what one account keeps is never read by the next one on this iPhone.
    static func key(_ base: String, in defaults: UserDefaults = .standard) -> String {
        "\(base).\(current(in: defaults) ?? "signedOut")"
    }

    /// The folder name for this account's files on the device.
    static func folderName(in defaults: UserDefaults = .standard) -> String {
        let id = current(in: defaults) ?? "signedOut"
        return String(id.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    }
}
