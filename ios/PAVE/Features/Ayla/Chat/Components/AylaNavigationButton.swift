import PAVECore
import SwiftUI

/// Under Ayla's answer when she points to a part of PAVE: "Open je kluis", "Open Eindstage" or "Open instellingen",
/// like the navigation button on the web. Parts that are not in the app yet say so instead.
struct AylaNavigationButton: View {
    let navigation: AylaReply.Navigation
    /// The title of the item, when she points to one.
    var itemTitle: String?
    let onOpen: () -> Void

    static func canOpen(_ screen: AylaScreen) -> Bool {
        [.vault, .vaultItem, .settings].contains(screen)
    }

    private var title: String {
        switch navigation.screen {
        case .vaultItem: itemTitle.map { "Open \($0)" } ?? AylaMessages.openVault
        case .settings: AylaMessages.openSettings
        default: AylaMessages.openVault
        }
    }

    private var icon: ImageResource {
        navigation.screen == .settings ? .iconSettings : .iconFolderSolid
    }

    var body: some View {
        Button {
            PaveHaptics.tap(.light)
            onOpen()
        } label: {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.gapChip)
                    .lineLimit(1)
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.brandGreen)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Color.surfaceTint, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
    }
}

/// Under Ayla's answer when it leans on the vault: which parts, such as "Uit je kluis: stages, diploma's". Ayla only
/// sees items where the user allowed it, so this shows what she used of those.
struct AylaUsedVault: View {
    let categories: [AylaVaultCategory]

    private var names: [String] {
        categories.compactMap { $0.category?.title.lowercased() }
    }

    var body: some View {
        if !names.isEmpty {
            HStack(spacing: 6) {
                Image(.iconFolderSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.brandGreen)
                    .accessibilityHidden(true)
                Text(AylaMessages.usedVault(names))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .padding(.leading, 4)
            .frame(minHeight: 28)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Above the text field while the conversation is about one item from the vault, with a way to drop it.
struct AylaContextChip: View {
    let title: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(.iconFolderSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.brandGreen)
                .accessibilityHidden(true)
            Text(AylaMessages.about(title))
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
            Button(action: onClear) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(AylaMessages.clearContext)
        }
        .padding(.leading, 12)
        .padding(.trailing, 2)
        .background(Color.white, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}
