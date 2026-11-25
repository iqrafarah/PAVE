import PAVECore
import SwiftUI

/// The front of your card in Profiel, like a pass in Wallet: PAVE, your photo and name, what you study, and the
/// evidence a school or employer verified.
struct SharePassFront: View {
    let name: String
    let photo: UIImage?
    let headline: String?
    let verified: [VaultItem]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                PaveMark(size: 4, color: .white)
                Text("PAVE")
                    .textStyle(.label)
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                PassChip(icon: .iconCheckBadgeSolid, title: SharingMessages.passVerified(verified.count, of: total))
            }
            HStack(spacing: 14) {
                AccountBadge(name: name, image: photo, size: 58)
                    .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? SharingMessages.you : name)
                        .textStyle(.emptyTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let headline {
                        Text(headline)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
            }
            if verified.isEmpty {
                Text(SharingMessages.passNoneVerified)
                    .textStyle(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(verified.prefix(3)) { item in
                        PassChip(icon: .iconCheckBadgeSolid, title: item.title)
                    }
                }
            }
            HStack {
                Spacer()
                PassChip(icon: .iconArrowPathSolid, title: SharingMessages.passTurn, isQuiet: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [Color.paveAccentFill, Color.paveAccentFill.mix(with: .black, by: 0.35)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // A large pixel slash in the corner, the same mark as the logo.
                PaveMark(count: 6, size: 34, color: .white)
                    .opacity(0.08)
                    .offset(x: 30, y: 24)
            }
        }
        .clipShape(.rect(cornerRadius: 20))
    }
}

/// A small white-on-colour chip on the pass.
private struct PassChip: View {
    let icon: ImageResource
    let title: String
    var isQuiet = false

    var body: some View {
        HStack(spacing: 5) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(isQuiet ? 0.8 : 1))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.white.opacity(isQuiet ? 0 : 0.18), in: .capsule)
    }
}
