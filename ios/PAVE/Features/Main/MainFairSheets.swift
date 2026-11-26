import PAVECore
import SwiftUI

/// What opens over any screen from outside: an employer or a poster scanned with the iPhone's camera, an employer's
/// inbox of the demo, and sharing that Ayla set up.
struct MainFairSheets: ViewModifier {
    let sharing: SharingModel
    let vault: VaultModel
    let model: AylaChatModel
    @Binding var fairEmployer: FairEmployerSlug?
    @Binding var employerInbox: EmployerInboxKey?
    @Binding var aylaShare: ShareTemplateChoice?

    /// Chosen on the employer's card: the composer opens once the card has gone.
    @State private var sharesBackWith: FairEmployer?

    func body(content: Content) -> some View {
        content
            .sheet(item: $fairEmployer, onDismiss: {
                guard let employer = sharesBackWith else { return }
                sharesBackWith = nil
                sharing.reloadApplications()
                aylaShare = ShareTemplateChoice(template: .fair, organisation: employer.name, withApplication: false)
            }) { opened in
                NavigationStack {
                    FairEmployerLoader(slug: opened.slug, vacancyID: opened.vacancyID, model: sharing) { employer in
                        sharesBackWith = employer
                        fairEmployer = nil
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(ApplyMessages.close) { fairEmployer = nil }
                        }
                    }
                }
                .environment(vault)
                .environment(model)
            }
            .sheet(item: $employerInbox) { opened in
                NavigationStack {
                    EmployerInboxView(slug: opened.slug, key: opened.key)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button(ApplyMessages.close) { employerInbox = nil } }
                        }
                }
            }
            .sheet(item: $aylaShare) { choice in
                ShareComposer(
                    model: sharing, template: choice.template, recipientOrganisation: choice.organisation, duration: choice.duration,
                    withApplication: choice.withApplication, doneTitle: SharingMessages.backToAyla
                ) { aylaShare = nil }
                .environment(vault)
            }
    }
}
