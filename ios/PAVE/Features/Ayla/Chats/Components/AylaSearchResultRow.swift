import SwiftUI

/// One result of the search, as in ChatGPT and on the web (AylaSearchDialog): an icon for its kind, the title and a line
/// under it with the words you typed in bold, and when it was last changed.
struct AylaSearchResultRow: View {
    enum Icon {
        case chat, project, item, file(VaultFileTypeIcon.Kind)
    }

    let icon: Icon
    let title: String
    let subtitle: String?
    let date: Date?
    let search: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                iconView
                    .frame(width: 32, height: 32)
                    .background(Color.paveSurfaceTint.opacity(isFile ? 0 : 1), in: .rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(AylaChatSearchRow.highlighted(title, search))
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(AylaChatSearchRow.highlighted(subtitle, search))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let date {
                    Text(AylaChatRow.when(date))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var isFile: Bool {
        if case .file = icon { true } else { false }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .chat: symbol(.iconChat)
        case .project: symbol(.iconFolderSolid)
        case .item: symbol(.iconDocumentText)
        case .file(let kind): VaultFileTypeIcon(kind: kind, size: 30)
        }
    }

    private func symbol(_ icon: ImageResource) -> some View {
        Image(icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .paveIconFrame(16)
            .foregroundStyle(Color.paveAccent)
            .accessibilityHidden(true)
    }
}
