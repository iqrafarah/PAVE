import PAVECore
import SwiftUI

/// Like the Privacy Report of iOS: in one place who looked at what in the last 30 days, and what can still be seen.
struct ShareReportSheet: View {
    let model: SharingModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let report = model.report
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        figure("\(report.active)", "Actief")
                        figure("\(report.looks)", "Bekeken")
                        figure("\(report.downloads)", "Gedownload")
                    }
                    Text(SharingMessages.reportSummary(report)).textStyle(.caption).foregroundStyle(Color.inkMuted)
                    if !report.byShare.isEmpty {
                        SharePanel(title: "Meest bekeken") {
                            ForEach(Array(report.byShare.enumerated()), id: \.element.shareID) { index, entry in
                                if let share = model.share(entry.shareID) {
                                    HStack {
                                        ShareTemplateIcon(template: share.template, isMuted: !share.isLive())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(share.recipient).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(1)
                                            Text("\(SharingMessages.looks(entry.looks)), laatst \(NotificationInboxRow.when(entry.lastLook))").textStyle(.caption).foregroundStyle(Color.inkMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    if index < report.byShare.count - 1 { Divider().padding(.leading, 62) }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.canvas)
            .navigationTitle(SharingMessages.report)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { dismiss() } } }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).textStyle(.emptyTitle).foregroundStyle(Color.paveAccent).monospacedDigit()
            Text(label).textStyle(.caption).foregroundStyle(Color.inkMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
        .accessibilityElement(children: .combine)
    }
}
