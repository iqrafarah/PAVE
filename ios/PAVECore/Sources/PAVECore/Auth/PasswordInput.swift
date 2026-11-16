/// What a password field keeps of what you type or paste.
public enum PasswordInput {
    /// Line breaks are left out, as a password field in a browser does: a password copied from Notes or Mail often
    /// brings one along, and then signing in fails. Spaces stay, because they can be part of a password.
    public static func cleaned(_ text: String) -> String {
        text.filter { !$0.isNewline }
    }
}
