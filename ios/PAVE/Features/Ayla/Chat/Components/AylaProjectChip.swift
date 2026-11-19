import SwiftUI

/// Above the text field while a new chat will start inside a project: "Nieuwe chat in Stage zoeken", with a cross to
/// start an ordinary chat instead (web getProjectChipLabel).
struct AylaProjectChip: View {
    let name: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(.iconFolderSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(14)
                .foregroundStyle(Color.paveAccent)
                .accessibilityHidden(true)
            Text(AylaMessages.projectChip(name))
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
            Button(action: onClear) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(10)
                    .foregroundStyle(Color.inkMuted)
                    .paveIconFrame(28)
                    .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("Gewone chat beginnen")
        }
        .padding(.leading, 12)
        .padding(.trailing, 2)
        .background(Color.paveSurfaceTint, in: .capsule)
    }
}
