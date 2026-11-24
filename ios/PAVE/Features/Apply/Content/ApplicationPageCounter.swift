import SwiftUI

/// How long the CV is with what is on now: one page, or more with a way to make it fit.
struct ApplicationPageCounter: View {
    let pages: Int
    var onFit: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(pages <= 1 ? Color.paveAccent : Color.warning)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(pages <= 1 ? ApplyMessages.fitsOnOnePage : ApplyMessages.pageCount(pages))
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Color.panel, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
            if pages > 1, let onFit {
                Button(ApplyMessages.makeItFit, action: onFit)
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
            }
        }
        .animation(.easeOut(duration: 0.2), value: pages)
    }
}
