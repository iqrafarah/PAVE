import PAVECore
import SwiftUI

/// What the vacancy asks for, against the CV as it is now: one line that says how much of it the CV shows, and on a
/// tap every requirement with where it stands. Evidence that is in the vault but off can be turned on here.
struct ApplicationCoverageCard: View {
    let model: ApplicationStudioModel

    @State private var isOpen = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        let requirements = model.requirements
        if !requirements.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.12)) { isOpen.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ApplyMessages.asked)
                                .textStyle(.bodyMedium)
                                .foregroundStyle(Color.ink)
                            Text(ApplyMessages.askedSummary(
                                covered: requirements.filter(\.isCovered).count, of: requirements.count,
                                available: requirements.filter { if case .available = $0.state { true } else { false } }.count
                            ))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(.iconChevronDown)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .paveIconHeight(7)
                            .foregroundStyle(Color.inkMuted)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityHint(isOpen ? "Tik om de eisen te verbergen" : "Tik om de eisen te zien")
                if isOpen {
                    ForEach(requirements) { requirement in
                        Divider().padding(.leading, 14)
                        ApplicationCoverageRow(requirement: requirement) { entryID in
                            PaveHaptics.selection()
                            model.setVisible(entryID, true)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .background(Color.panel, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
        }
    }
}
