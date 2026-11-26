import PAVECore
import SwiftUI

/// Everything from the vault that can go on the CV, per part, each to turn on or off.
struct ApplicationContentList: View {
    let model: ApplicationStudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(model.draft.cv.sections.filter { !$0.entries.isEmpty }) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(ApplyMessages.section(section.kind))
                        .textStyle(.label)
                        .foregroundStyle(Color.inkMuted)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                            ApplicationContentRow(entry: entry, item: model.item(entry.sourceItemID), choice: model.choices[entry.id], marksHidden: model.items.contains { $0.aylaAllowedAt != nil }) { isOn in
                                model.setVisible(entry.id, isOn)
                            }
                            if index < section.entries.count - 1 {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .background(Color.panel, in: .rect(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
                }
            }
        }
    }
}
