import PAVECore
import SwiftUI

/// The pages an answer Ayla looked up comes from, under the answer: tap one to check it yourself.
struct AylaSources: View {
    let sources: [AylaBlock.Source]
    let onOpen: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AylaMessages.sourcesTitle)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(sources, id: \.self) { source in
                        Button { onOpen(source.url) } label: {
                            HStack(spacing: 6) {
                                Image(.iconGlobeEuropeAfricaSolid)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .paveIconHeight(14)
                                    .foregroundStyle(Color.paveAccent)
                                    .accessibilityHidden(true)
                                Text(verbatim: source.site)
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(Color.paveSurfaceTint, in: .capsule)
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pave)
                        .accessibilityLabel(source.title)
                        .accessibilityHint(AylaMessages.sourceHint)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
