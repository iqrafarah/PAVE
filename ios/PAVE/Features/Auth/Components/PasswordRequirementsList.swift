import PAVECore
import SwiftUI

struct PasswordRequirementsList: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PasswordRequirement.heading)
                .textStyle(.eyebrow)
                .foregroundStyle(Color.brandGreen)

            ForEach(PasswordRequirement.allCases, id: \.self) { requirement in
                let isMet = requirement.isMet(by: password)
                HStack(spacing: 8) {
                    Image(isMet ? .iconCheck : .iconRequirementBullet)
                        .resizable()
                        .frame(width: isMet ? 16 : 4, height: isMet ? 16 : 4)
                        .accessibilityHidden(true)
                    Text(requirement.title)
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(isMet ? "Voldaan" : "Niet voldaan")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
        .animation(.easeOut(duration: 0.15), value: password)
    }
}

#Preview {
    VStack(spacing: 16) {
        PasswordRequirementsList(password: "")
        PasswordRequirementsList(password: "BrightFuture!2026")
    }
    .padding(32)
}
