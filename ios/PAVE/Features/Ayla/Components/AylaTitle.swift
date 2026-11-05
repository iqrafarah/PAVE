import SwiftUI

/// "/ Ayla" in the middle of the header.
struct AylaTitle: View {
    var body: some View {
        HStack(alignment: .center, spacing: 3.3) {
            AylaMark(count: 5, size: 5.333)
            Text("Ayla")
                .textStyle(.aylaTitle)
                .foregroundStyle(Color.brandGreen)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ayla")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    AylaTitle()
        .padding()
}
