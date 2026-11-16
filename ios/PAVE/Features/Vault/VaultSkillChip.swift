import SwiftUI

/// A skill on a vault item, such as "Leiderschap".
struct VaultSkillChip: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.tileFill, in: .rect(cornerRadius: 6))
    }
}

#Preview {
    HStack {
        VaultSkillChip(text: "Leiderschap")
        VaultSkillChip(text: "+2")
    }
    .padding()
}
