import PAVECore
import SwiftUI

/// E-mail, phone and city, each with its icon: stacked in a side column, or in one row. While editing, an empty phone
/// or city shows what goes there, as the profile does; on paper it is left out.
struct CVContactList: View {
    let cv: CVContent
    let theme: ApplicationTheme
    var isRow = false
    var onDark = false
    var iconColor: Color?

    @Environment(\.applicationIsEditing) private var isEditing

    private var lines: [(icon: ImageResource, text: String, isHint: Bool)] {
        [(.iconEnvelopeOutline, cv.email, ""), (.iconPhoneOutline, cv.phone, ApplyMessages.phone), (.iconMapPinOutline, cv.city, ApplyMessages.city)]
            .compactMap { icon, text, hint in
                if !text.isEmpty { return (icon, text, false) }
                return isEditing && !hint.isEmpty ? (icon, hint, true) : nil
            }
    }

    var body: some View {
        let layout = isRow ? AnyLayout(HStackLayout(spacing: 14)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 7))
        layout {
            ForEach(lines, id: \.text) { line in
                HStack(spacing: 6) {
                    Image(line.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(iconColor ?? (onDark ? .white.opacity(0.85) : theme.accent))
                    Text(line.text)
                        .font(theme.body(8.5))
                        .italic(line.isHint)
                        .foregroundStyle(onDark ? .white.opacity(line.isHint ? 0.55 : 0.9) : (line.isHint ? theme.muted : theme.ink))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .opacity(line.isHint && !onDark ? 0.75 : 1)
            }
        }
    }
}

extension EnvironmentValues {
    /// The page is in the editor: empty parts show what goes there. Off for the gallery and the pdf.
    @Entry var applicationIsEditing = false
}
