import PAVECore
import SwiftUI

/// Right after leaving your card: the tick, what happens next, and that the employer is not really connected.
struct QuickApplySent: View {
    let employer: FairEmployer
    let application: FairApplication
    let onDone: () -> Void

    @State private var landed = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(.iconCheck)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Color.paveAccentFill, in: .circle)
                .scaleEffect(landed ? 1 : 0.5)
                .opacity(landed ? 1 : 0)
                .accessibilityHidden(true)
            Text(SharingMessages.quickApplySentTitle).textStyle(.emptyTitle).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
            Text(SharingMessages.quickApplySentText(employer.name, vacancy: application.vacancyTitle))
                .textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            PavePrimaryButton(title: ApplyMessages.done, action: onDone)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.4)) { landed = true }
        }
    }
}
