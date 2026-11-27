import PAVECore
import SwiftUI

/// One share: its code and link, how long still, who looked, and pausing, extending or taking it back.
struct ShareDetailView: View {
    let model: SharingModel
    let shareID: String

    @Environment(VaultModel.self) private var vault
    @State private var confirmsRevoke = false
    @State private var showsPreview = false

    var body: some View {
        if let share = model.share(shareID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(share)
                    if share.isLive() {
                        ShareCodeCard(model: model, share: share)
                            .opacity(share.state() == .paused ? 0.35 : 1)
                        actions(share)
                    }
                    ShareLooksList(looks: share.looks)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas)
            .navigationTitle(share.recipientName)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(SharingMessages.revokeQuestion(share.recipientName), isPresented: $confirmsRevoke, titleVisibility: .visible) {
                Button(SharingMessages.revoke, role: .destructive) { Task { await model.revoke(share) } }
            } message: {
                Text(SharingMessages.revokeHint)
            }
            .onAppear {
                if model.asksToRevoke == share.id {
                    model.asksToRevoke = nil
                    confirmsRevoke = true
                }
            }
            .navigationDestination(isPresented: $showsPreview) {
                ShareRecipientPreview(share: share, items: vault.items.filter { share.itemIDs.contains($0.id) })
            }
        }
    }

    private func header(_ share: ProfileShare) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ShareTemplateIcon(template: share.template, isMuted: !share.isLive())
            VStack(alignment: .leading, spacing: 3) {
                Text(share.title).textStyle(.calloutTitle).foregroundStyle(Color.ink)
                Text(share.recipient).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                Text(SharingMessages.remaining(share)).textStyle(.caption).foregroundStyle(share.state() == .paused ? Color.warning : Color.paveAccent)
                if let purpose = share.purpose, purpose != share.title { Text(purpose).textStyle(.caption).foregroundStyle(Color.inkMuted) }
            }
        }
    }

    /// What you can do with it, as rows in one group: pause or resume, extend, see what they see, take back.
    private func actions(_ share: ProfileShare) -> some View {
        SharePanel(title: SharingMessages.manage) {
            Button { Task { await model.setPaused(share.state() != .paused, share) } } label: {
                ShareActionRow(
                    icon: share.state() == .paused ? .iconPlaySolid : .iconPauseSolid,
                    title: share.state() == .paused ? SharingMessages.resume : SharingMessages.pause
                )
            }
            .buttonStyle(.pave)
            ShareRowDivider()
            Menu {
                ForEach([ShareDuration.day, .week, .twoWeeks, .month], id: \.self) { duration in
                    Button("+ \(SharingMessages.duration(duration))") { Task { await model.extend(share, by: duration) } }
                }
            } label: {
                ShareActionRow(icon: .iconClockSolid, title: SharingMessages.extend)
            }
            ShareRowDivider()
            Button { showsPreview = true } label: { ShareActionRow(icon: .iconUserSolid, title: SharingMessages.preview) }
                .buttonStyle(.pave)
            ShareRowDivider()
            Button(role: .destructive) { confirmsRevoke = true } label: {
                ShareActionRow(icon: .iconTrashSolid, title: SharingMessages.revoke, isDestructive: true)
            }
            .buttonStyle(.pave)
        }
        .disabled(model.busyShareID == share.id)
    }
}
