import PAVECore
import SwiftUI

/// Werkgever-modus in the demo: the recruiter's view of who applied at the stand, opened with the employer's secret
/// key. Invite someone for a talk at a moment; they get it in PAVE.
struct EmployerInboxView: View {
    let slug: String
    let key: String

    @State private var inbox: EmployerInbox?
    @State private var problem: String?
    @State private var inviting: InboxApplication?
    private var service: FairInboxService? { FairInboxServiceFactory.make() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let inbox {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SharingMessages.inboxTitle).textStyle(.label).foregroundStyle(Color.paveAccent)
                        Text(inbox.name).textStyle(.emptyTitle).foregroundStyle(Color.ink)
                        Text(SharingMessages.inboxHint).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    if inbox.applications.isEmpty {
                        PaveEmptyState(icon: .iconBriefcase, title: SharingMessages.inboxEmpty, message: SharingMessages.inboxEmptyHint)
                    }
                    ForEach(inbox.applications) { application in
                        EmployerInboxCard(application: application) { inviting = application }
                    }
                } else if let problem {
                    PaveEmptyState(icon: .iconBriefcase, title: SharingMessages.fairNotFound, message: problem)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .refreshable { await load() }
        .task {
            await load()
            // The demo goes quick: new cards show up without pulling.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await load()
            }
        }
        .sheet(item: $inviting) { application in
            EmployerInviteSheet(application: application) { moment, message in
                guard let service else { return false }
                guard let updated = try? await service.invite(application.id, at: moment, message: message, slug: slug, key: key) else { return false }
                inbox = updated
                return true
            }
        }
    }

    private func load() async {
        guard let service else {
            problem = SharingMessages.fairNoService
            return
        }
        do {
            inbox = try await service.inbox(slug: slug, key: key)
            problem = nil
        } catch ShareError.notSignedIn {
            problem = SharingMessages.inboxWrongKey
        } catch {
            if inbox == nil { problem = SharingMessages.fairLoadFailed }
        }
    }
}
