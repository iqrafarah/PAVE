import Foundation

/// Shows an email address without giving it away, like `web/app/utils/email.ts`: `r***@student.example.edu`.
public enum EmailMask {
    public static func masked(_ email: String) -> String {
        let parts = email.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count >= 2, let first = parts[0].first, !parts[1].isEmpty else { return email }
        return "\(first)***@\(parts[1])"
    }
}
