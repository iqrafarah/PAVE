import PAVECore
import SwiftUI

struct PasswordRequirementsList: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PasswordRequirement.heading)
                .textStyle(.eyebrow)
                .foregroundStyle(Color.paveAccent)

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

            Text(AuthMessages.remainingRules(remainingCount))
                .textStyle(.label)
                .foregroundStyle(Color.ink)
                .padding(.top, 4)
                .contentTransition(.numericText())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
        .animation(.easeOut(duration: 0.15), value: password)
        // A light tap the moment the last requirement is met.
        .sensoryFeedback(.impact(weight: .light), trigger: remainingCount == 0) { _, isNow in isNow }
    }

    private var remainingCount: Int {
        PasswordRequirement.allCases.filter { !$0.isMet(by: password) }.count
    }
}

#Preview {
    VStack(spacing: 16) {
        PasswordRequirementsList(password: "")
        PasswordRequirementsList(password: "BrightFuture!2026")
    }
    .padding(32)
}
