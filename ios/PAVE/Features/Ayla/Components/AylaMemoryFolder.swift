import PAVECore
import SwiftUI

/// A folder in "Wat Ayla over je weet": the category with its icon and how much Ayla remembers in it.
struct AylaMemoryFolder: View {
    let category: AylaMemory.Category
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: category.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.brandGreen)
                .frame(width: 40, height: 40)
                .background(category.tint, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            Spacer(minLength: 14)
            Text(category.title)
                .textStyle(.tileTitle)
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(count == 0 ? "Leeg" : count == 1 ? "1 ding" : "\(count) dingen")
                .textStyle(.tileCount)
                .foregroundStyle(Color.inkSoft)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(Color.white, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .opacity(count == 0 ? 0.75 : 1)
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.title), \(count == 0 ? "leeg" : count == 1 ? "1 ding" : "\(count) dingen")")
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        AylaMemoryFolder(category: .education, count: 2)
        AylaMemoryFolder(category: .work, count: 1)
        AylaMemoryFolder(category: .workStyle, count: 0)
        AylaMemoryFolder(category: .interests, count: 3)
    }
    .padding()
    .background(Color.canvas)
}
