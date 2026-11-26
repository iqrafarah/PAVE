import PAVECore
import SwiftUI

/// One thing the vacancy asks for: the skill, the line from the vacancy, and whether the CV shows it.
struct ApplicationCoverageRow: View {
    let requirement: ApplicationCoverage.Requirement
    let onTurnOn: (String) -> Void

    private var color: Color {
        switch requirement.state {
        case .shown: .paveAccent
        case .named, .available: .warning
        case .missing: .inkMuted
        }
    }

    private var available: String? {
        if case .available(let entries) = requirement.state { return entries.first }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(requirement.state == .missing ? Color.clear : color)
                .overlay { Circle().strokeBorder(color, lineWidth: 1.5) }
                .frame(width: 10, height: 10)
                .padding(.top, 5)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(requirement.skill)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !requirement.text.isEmpty, requirement.text.caseInsensitiveCompare(requirement.skill) != .orderedSame {
                    Text(requirement.text)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(ApplyMessages.coverage(requirement.state))
                    .textStyle(.caption)
                    .foregroundStyle(requirement.isCovered ? Color.paveAccent : Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let available {
                Button(ApplyMessages.turnOn) { onTurnOn(available) }
                    .textStyle(.chip)
                    .foregroundStyle(Color.paveAccent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.paveSurfaceTint, in: .capsule)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
                    .buttonStyle(.pave)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
