import PAVECore
import SwiftUI

/// The top of Profiel: who you are as others will see you, how much of your evidence is verified, and a quick way to
/// let someone scan you at a fair.
struct ShareProfileCard: View {
    let onQuickShare: () -> Void

    @Environment(ProfileModel.self) private var profile
    @Environment(VaultModel.self) private var vault

    private var name: String { profile.profile.fullName ?? profile.profile.displayName ?? "" }

    /// As on the CV: the newest diploma, "Student …".
    private var headline: String? {
        vault.items
            .filter { $0.category == .diplomas }
            .max { ($0.period ?? "") < ($1.period ?? "") }
            .map { "Student \($0.title)" }
    }

    private var verified: Int { vault.items.filter { $0.status == .verified }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AccountBadge(name: name, image: profile.avatar, size: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? SharingMessages.you : name)
                        .textStyle(.emptyTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if let headline {
                        Text(headline)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(2)
                    }
                    Text(SharingMessages.evidenceCount(vault.items.count, verified: verified))
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Button(action: onQuickShare) {
                HStack(spacing: 8) {
                    Image(.iconQrcode)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(17)
                        .accessibilityHidden(true)
                    Text(SharingMessages.quickShare)
                        .textStyle(.button)
                }
                .foregroundStyle(Color.paveAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.paveSurfaceTint, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.pave)
        }
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }
}
