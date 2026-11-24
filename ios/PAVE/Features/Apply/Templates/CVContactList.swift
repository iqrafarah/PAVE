import PAVECore
import SwiftUI

/// E-mail, phone and city, each with its icon: stacked in a side column, or in one row.
struct CVContactList: View {
    let cv: CVContent
    let theme: ApplicationTheme
    var isRow = false
    var onDark = false
    var iconColor: Color?

    private var lines: [(ImageResource, String)] {
        [(.iconEnvelopeOutline, cv.email), (.iconPhoneOutline, cv.phone), (.iconMapPinOutline, cv.city)].filter { !$0.1.isEmpty }
    }

    var body: some View {
        let layout = isRow ? AnyLayout(HStackLayout(spacing: 14)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 7))
        layout {
            ForEach(lines, id: \.1) { icon, text in
                HStack(spacing: 6) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(iconColor ?? (onDark ? .white.opacity(0.85) : theme.accent))
                    Text(text)
                        .font(theme.body(8.5))
                        .foregroundStyle(onDark ? .white.opacity(0.9) : theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}
