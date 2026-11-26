import PAVECore
import SwiftUI

/// From a scanned code to the employer's card: the "found" moment while it loads and a beat after, then the card.
/// Used by the scanner in Profiel and when the iPhone's own camera opens PAVE.
struct FairEmployerLoader: View {
    let slug: String
    /// From a poster: the one vacancy to apply for straight away.
    var vacancyID: String?
    let model: SharingModel
    let onShareBack: (FairEmployer) -> Void

    @State private var employer: FairEmployer?
    @State private var isShown = false
    @State private var problem: String?
    @State private var attempt = 0
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let employer, isShown {
                FairEmployerView(employer: employer, model: model, applyingTo: vacancyID) { onShareBack(employer) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if let problem {
                VStack(spacing: 16) {
                    PaveEmptyState(icon: .iconBriefcase, title: SharingMessages.fairNotFound, message: problem)
                    PaveSecondaryButton(title: SharingMessages.tryAgain) { attempt += 1 }
                        .frame(maxWidth: 260)
                }
            } else {
                FairFoundView(name: employer?.name, stand: employer?.stand)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: isShown)
        .navigationTitle(isShown ? employer?.name ?? "" : "")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(slug)-\(attempt)") {
            problem = nil
            guard let service = model.service else {
                problem = SharingMessages.fairNoService
                return
            }
            do {
                employer = try await service.employer(slug: slug)
                if let employer { FairDay.record(.scanned(employer: employer.name, slug: employer.slug, stand: employer.stand)) }
                // A moment to see what was found.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 1100))
                isShown = true
            } catch {
                problem = SharingMessages.fairLoadFailed
            }
        }
    }
}
