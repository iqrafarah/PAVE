import PAVECore
import SwiftUI

/// A project in the chat list, as on the web (AylaProjectList): its icon in its own colour and its name. Tapping it
/// opens its page and its chats underneath; tapping it again folds them. The plain folder shows open while it is open.
struct AylaProjectRow: View {
    let project: AylaProject
    let isOpen: Bool
    var isDropTarget = false
    let onTap: () -> Void

    private var icon: ImageResource {
        guard project.icon == nil || project.icon == .folder else { return project.iconImage }
        return isOpen ? .iconFolderSolid : .iconFolderClosedSolid
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(16)
                    .foregroundStyle(project.tint)
                Text(project.name)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTarget ? Color.paveSurfaceTint : .clear)
                .strokeBorder(isDropTarget ? Color.paveAccent : .clear, lineWidth: 1.5)
        }
        .hoverEffect(.highlight)
        .animation(.easeOut(duration: 0.15), value: isDropTarget)
        .accessibilityLabel("\(project.name), project")
        .accessibilityValue(isOpen ? "Chats getoond" : "Chats verborgen")
        .accessibilityHint(isOpen ? "Verbergt de chats" : "Opent het project en toont de chats")
    }
}
