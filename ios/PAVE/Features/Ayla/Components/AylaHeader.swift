import SwiftUI

struct AylaHeader: View {
    var showsMenu = true
    var onMenu: () -> Void = {}
    var onNewConversation: () -> Void

    var body: some View {
        HStack {
            if showsMenu {
                PaveIconButton(icon: .iconMenu, label: "Gesprekken", action: onMenu)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            HStack(alignment: .center, spacing: 8) {
                AylaMark(count: 5, size: 5.333)
                Text("Ayla")
                    .textStyle(.aylaTitle)
                    .foregroundStyle(Color.brandGreen)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            PaveIconButton(icon: .iconChat, label: "Nieuw gesprek", action: onNewConversation)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40)
                .fill(.regularMaterial)
                .overlay {
                    UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40)
                        .fill(Color.canvas.opacity(0.7))
                }
                .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
                .ignoresSafeArea(edges: .top)
        }
    }
}

#Preview {
    VStack {
        AylaHeader(onNewConversation: {})
        Spacer()
    }
    .background(Color.canvas)
}
