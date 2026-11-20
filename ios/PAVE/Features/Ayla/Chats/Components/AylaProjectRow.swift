import PAVECore
import SwiftUI

/// A project in the chat list (web AylaProjectList): its icon in its own colour, its name and how many chats it holds.
/// Tapping it opens its page; the arrow opens or closes its chats underneath. A chat dragged onto it goes into the project.
struct AylaProjectRow: View {
    let project: AylaProject
    let count: Int
    let isOpen: Bool
    var isDropTarget = false
    let onOpen: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Image(project.iconImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(20)
                        .foregroundStyle(project.tint)
                    Text(project.name)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if project.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 8)
                    if count > 0 {
                        Text("\(count)")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.leading, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(project.name), project\(project.isPinned ? ", vastgezet" : ""), \(count == 1 ? "1 chat" : "\(count) chats")")
            .accessibilityHint("Opent het project")

            Button(action: onToggle) {
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: 44, height: 48)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isOpen ? "Chats van \(project.name) verbergen" : "Chats van \(project.name) tonen")
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTarget ? Color.paveSurfaceTint : .clear)
                .strokeBorder(isDropTarget ? Color.paveAccent : .clear, lineWidth: 1.5)
        }
        .contentShape(.rect(cornerRadius: 12))
        .hoverEffect(.highlight)
        .animation(.easeOut(duration: 0.15), value: isDropTarget)
    }
}
