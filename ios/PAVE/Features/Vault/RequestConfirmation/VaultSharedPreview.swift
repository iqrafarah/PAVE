import PAVECore
import SwiftUI

/// "Dit ziet de ontvanger": what of the evidence the person who confirms it would get to see, so nothing is shared
/// without the user knowing what.
struct VaultSharedPreview: View {
    let item: VaultItem
    let documentCount: Int

    private var lines: [String] {
        var lines = [VaultMessages.sharedTitle(item.title, kind: item.category.singularTitle)]
        if let organisation = item.organisationName, !organisation.isEmpty { lines.append(organisation) }
        if let period = item.period { lines.append(period) }
        if let description = item.description, !description.isEmpty { lines.append(VaultMessages.sharedDescription) }
        if documentCount > 0 { lines.append(VaultMessages.sharedFiles(documentCount)) }
        if !item.skills.isEmpty { lines.append(VaultMessages.sharedSkills(item.skills.count)) }
        return lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(.iconCheck)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(14)
                        .foregroundStyle(Color.paveAccent)
                        .accessibilityHidden(true)
                    Text(line)
                        .textStyle(.caption)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.railBorder, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
