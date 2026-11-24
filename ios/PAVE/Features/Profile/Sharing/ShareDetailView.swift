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
                    if share.isLive() {
                        ShareLinkRow(icon: .iconUserSolid, title: SharingMessages.preview) { showsPreview = true }
                            .background(Color.panel, in: .rect(cornerRadius: 16))
                            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
                    }
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
            .sheet(isPresented: $showsPreview) {
                ShareRecipientPreview(share: share, items: vault.items.filter { share.itemIDs.contains($0.id) })
            }
        }
    }

    private func header(_ share: ProfileShare) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ShareTemplateIcon(template: share.template, isMuted: !share.isLive())
            VStack(alignment: .leading, spacing: 3) {
                Text(share.title).textStyle(.calloutTitle).foregroundStyle(Color.ink)
                Text(share.recipient).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                Text(SharingMessages.remaining(share)).textStyle(.caption).foregroundStyle(share.state() == .paused ? Color.warning : Color.paveAccent)
                if let purpose = share.purpose { Text(purpose).textStyle(.caption).foregroundStyle(Color.inkMuted) }
            }
        }
    }

    private func actions(_ share: ProfileShare) -> some View {
        HStack(spacing: 10) {
            PaveSecondaryButton(title: share.state() == .paused ? SharingMessages.resume : SharingMessages.pause) {
                Task { await model.setPaused(share.state() != .paused, share) }
            }
            Menu {
                ForEach([ShareDuration.day, .week, .twoWeeks, .month], id: \.self) { duration in
                    Button("+ \(SharingMessages.duration(duration))") { Task { await model.extend(share, by: duration) } }
                }
            } label: {
                Text(SharingMessages.extend)
                    .textStyle(.button)
                    .foregroundStyle(Color.paveAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.panel, in: .capsule)
                    .overlay { Capsule().strokeBorder(Color.paveAccent, lineWidth: 1.5) }
            }
            Button(role: .destructive) { confirmsRevoke = true } label: {
                Text(SharingMessages.revoke)
                    .textStyle(.button)
                    .foregroundStyle(Color.critical)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.criticalSurface, in: .capsule)
            }
            .buttonStyle(.pave)
        }
        .disabled(model.busyShareID == share.id)
    }
}
