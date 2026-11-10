import SwiftUI

/// What a screen shows while there is nothing in it yet.
struct PaveEmptyState: View {
    let icon: ImageResource
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 72, height: 72)
                .background(Color.surfaceTint, in: .rect(cornerRadius: 22))
                .padding(.bottom, 22)
            Text(title)
                .textStyle(.emptyTitle)
                .foregroundStyle(Color.ink)
                .padding(.bottom, 8)
            Text(message)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 313)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PaveEmptyState(icon: .iconFolder, title: "Je kluis is nog leeg", message: "Hier bewaar je straks je diploma's, certificaten, projecten en ervaringen.")
        .padding()
}
