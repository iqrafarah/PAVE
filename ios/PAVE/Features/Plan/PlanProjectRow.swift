import PAVECore
import SwiftUI

/// The project a plan belongs to, on the plan's page. New chats of the plan then start in that project, so Ayla uses
/// its instructions and sources. Tap to choose another project or none.
struct PlanProjectRow: View {
    let plan: PavePlan
    let projects: [AylaProject]
    let onChoose: (String?) -> Void

    private var project: AylaProject? { projects.first { $0.id == plan.projectID } }

    var body: some View {
        if !projects.isEmpty {
            Menu {
                Picker(PlanMessages.project, selection: Binding(get: { project?.id ?? "" }, set: { onChoose($0.isEmpty ? nil : $0) })) {
                    Text(PlanMessages.noProject).tag("")
                    ForEach(projects) { option in Text(option.name).tag(option.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    if let project {
                        AylaProjectBadge(project: project, size: 36)
                    } else {
                        Image(.iconFolderSolid)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .paveIconFrame(16)
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 36, height: 36)
                            .background(Color.canvas, in: .rect(cornerRadius: 10))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project?.name ?? PlanMessages.linkProject)
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Text(project == nil ? PlanMessages.linkProjectHint : PlanMessages.linkedProjectHint)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(.iconChevronDown)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconHeight(6)
                        .foregroundStyle(Color.inkMuted)
                        .accessibilityHidden(true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panel, in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
                .contentShape(.rect(cornerRadius: 16))
            }
            .accessibilityLabel("\(PlanMessages.project): \(project?.name ?? PlanMessages.noProject)")
        }
    }
}
