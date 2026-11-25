import PAVECore
import SwiftUI

/// From a scanned code to the employer's card: the "found" moment while it loads and a beat after, then the card.
/// Used by the scanner in Profiel and when the iPhone's own camera opens PAVE.
struct FairEmployerLoader: View {
    let slug: String
    let model: SharingModel
    let onShareBack: (FairEmployer) -> Void

    @State private var employer: FairEmployer?
    @State private var isShown = false
    @State private var problem: String?
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let employer, isShown {
                FairEmployerView(employer: employer) { onShareBack(employer) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if let problem {
                PaveEmptyState(icon: .iconBriefcase, title: SharingMessages.fairNotFound, message: problem)
            } else {
                FairFoundView(name: employer?.name, stand: employer?.stand)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: isShown)
        .navigationTitle(isShown ? employer?.name ?? "" : "")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: slug) {
            guard let service = model.service else {
                problem = SharingMessages.fairNoService
                return
            }
            do {
                employer = try await service.employer(slug: slug)
                // A moment to see what was found.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 1100))
                isShown = true
            } catch {
                problem = SharingMessages.fairLoadFailed
            }
        }
    }
}
