import PAVECore
import SwiftUI

/// A project in the chat list (web AylaProjectList): its name with how many chats it holds. Tapping it opens or closes
/// its chats underneath; a chat dragged onto it goes into the project.
struct AylaProjectRow: View {
    let project: AylaProject
    let count: Int
    let isOpen: Bool
    var isDropTarget = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(.iconFolderOutline)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(20)
                    .foregroundStyle(Color.paveAccent)
                Text(project.name)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if project.isPinned {
                    Image(.iconPin)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color.inkMuted)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                if count > 0 {
                    Text("\(count)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDropTarget ? Color.paveSurfaceTint : .clear)
                    .strokeBorder(isDropTarget ? Color.paveAccent : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .animation(.easeOut(duration: 0.15), value: isDropTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), project\(project.isPinned ? ", vastgezet" : ""), \(count == 1 ? "1 chat" : "\(count) chats")")
        .accessibilityValue(isOpen ? "Open" : "Dicht")
        .accessibilityHint(isOpen ? "Verbergt de chats" : "Toont de chats")
    }
}
