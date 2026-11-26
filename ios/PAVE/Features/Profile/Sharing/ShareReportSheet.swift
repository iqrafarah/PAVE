import PAVECore
import SwiftUI

/// "Wie keek er": like the Privacy Report of iOS, every look at what you shared, newest first and per day: who, what
/// they saw, viewed or downloaded, and when. What is still visible stops in one tap, right next to it.
struct ShareReportSheet: View {
    let model: SharingModel
    @Environment(\.dismiss) private var dismiss
    @State private var opened: OpenedShare?
    @State private var stopping: ProfileShare?

    private struct OpenedShare: Identifiable { let id: String }

    private static let window: TimeInterval = 30 * 86_400

    var body: some View {
        let report = model.report
        let days = ShareTimeline.days(model.shares, since: .now.addingTimeInterval(-Self.window))
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        figure("\(model.live.count)", SharingMessages.whoLookedActive)
                        figure("\(report.looks)", SharingMessages.whoLookedViews)
                        figure("\(report.downloads)", SharingMessages.whoLookedDownloads)
                    }
                    Text(SharingMessages.whoLookedIntro)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if days.isEmpty {
                        PaveEmptyState(icon: .iconEyeSolid, title: SharingMessages.whoLookedEmptyTitle, message: SharingMessages.whoLookedEmpty)
                            .padding(.top, 20)
                    } else {
                        ForEach(days) { day in
                            SharePanel(title: SharingMessages.whoLookedDay(day.start)) {
                                ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                                    row(entry)
                                    if index < day.entries.count - 1 { ShareRowDivider(inset: 60) }
                                }
                            }
                        }
                    }
                    let live = model.live
                    if !live.isEmpty {
                        SharePanel(title: SharingMessages.whoLookedStillVisible) {
                            ForEach(Array(live.enumerated()), id: \.element.id) { index, share in
                                visible(share)
                                if index < live.count - 1 { ShareRowDivider(inset: 60) }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas)
            .navigationTitle(SharingMessages.report)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { dismiss() } } }
            .sheet(item: $opened) { opened in
                NavigationStack {
                    ShareDetailView(model: model, shareID: opened.id)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { self.opened = nil } } }
                }
            }
            .confirmationDialog(SharingMessages.whoLookedStopQuestion, isPresented: Binding(get: { stopping != nil }, set: { if !$0 { stopping = nil } }), titleVisibility: .visible, presenting: stopping) { share in
                Button(SharingMessages.quickShareStop, role: .destructive) {
                    Task {
                        await model.revoke(share)
                        ShareWatchBridge.clear(share.id)
                        PaveHaptics.success()
                    }
                }
            } message: { share in
                Text(SharingMessages.whoLookedStopHint(share.recipient))
            }
        }
    }

    private func row(_ entry: ShareTimeline.Entry) -> some View {
        Button { opened = OpenedShare(id: entry.share.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                ShareTemplateIcon(template: entry.share.template, isMuted: !entry.share.isLive())
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.who).textStyle(.listTitle).foregroundStyle(Color.ink).lineLimit(2).multilineTextAlignment(.leading)
                    Text(SharingMessages.whoLookedWhat(entry.look.action == .download, title: entry.share.title))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.leading)
                    if entry.namedThemselves {
                        Text(SharingMessages.whoLookedSaid(entry.share.recipient))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Text(entry.look.date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "nl_NL"))))
                    .textStyle(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
    }

    private func visible(_ share: ProfileShare) -> some View {
        HStack(spacing: 12) {
            ShareTemplateIcon(template: share.template)
            VStack(alignment: .leading, spacing: 3) {
                Text(share.recipient).textStyle(.listTitle).foregroundStyle(Color.ink).lineLimit(2)
                Text(SharingMessages.whoLookedUntil(share.expiresAt, looks: share.looks.count))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 8)
            Button(SharingMessages.whoLookedStop) { stopping = share }
                .textStyle(.chip)
                .foregroundStyle(Color.critical)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color.canvas, in: .capsule)
                .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
                .buttonStyle(.pave)
                .accessibilityLabel(SharingMessages.whoLookedStopLabel(share.recipient))
        }
        .padding(14)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).textStyle(.emptyTitle).foregroundStyle(Color.paveAccent).monospacedDigit()
            Text(label).textStyle(.caption).foregroundStyle(Color.inkMuted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
        .accessibilityElement(children: .combine)
    }
}
