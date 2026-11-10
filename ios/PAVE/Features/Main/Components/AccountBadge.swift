import SwiftUI

/// A round badge with the first letter of the user's name.
struct AccountBadge: View {
    let name: String?

    var body: some View {
        Group {
            if let initial = name?.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased())
                    .textStyle(.action)
            } else {
                Image(.iconPerson)
                    .renderingMode(.template)
            }
        }
        .foregroundStyle(Color.brandGreen)
        .frame(width: 44, height: 44)
        .background(Color.surfaceTint, in: .circle)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        AccountBadge(name: "Daaf")
        AccountBadge(name: nil)
    }
    .padding()
}
