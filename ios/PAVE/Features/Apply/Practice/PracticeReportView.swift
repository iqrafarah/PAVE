import PAVECore
import SwiftUI

/// The report of a practice interview: how it went, what went well, what can be better, and example answers built on
/// your own words and evidence.
struct PracticeReportView: View {
    let report: PracticeReport
    let vacancy: Vacancy

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    AylaLetter(color: Color.paveAccent).frame(width: 13, height: 13)
                    Text(ApplyMessages.practiceReportFor(vacancy)).textStyle(.caption).foregroundStyle(Color.paveAccent)
                }
                Text(report.verdict).textStyle(.bodyMedium).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                Text(ApplyMessages.practiceReportDate(report.madeAt)).textStyle(.caption).foregroundStyle(Color.inkMuted)
            }
            if !report.strengths.isEmpty { points(ApplyMessages.practiceStrengths, report.strengths, icon: .iconCheckCircleSolid) }
            if !report.improve.isEmpty { points(ApplyMessages.practiceImprove, report.improve, icon: .iconArrowRightSolid) }
            if !report.examples.isEmpty {
                SharePanel(title: ApplyMessages.practiceExamples) {
                    ForEach(Array(report.examples.enumerated()), id: \.offset) { index, example in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(example.question).textStyle(.listTitle).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                            Text("“\(example.answer)”").textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < report.examples.count - 1 { ShareRowDivider(inset: 14) }
                    }
                }
            }
        }
    }

    private func points(_ title: String, _ lines: [String], icon: ImageResource) -> some View {
        SharePanel(title: title) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 10) {
                    Image(icon).renderingMode(.template).resizable().scaledToFit().paveIconFrame(15)
                        .foregroundStyle(Color.paveAccent).padding(.top, 2).accessibilityHidden(true)
                    Text(line).textStyle(.bodyMedium).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                if index < lines.count - 1 { ShareRowDivider(inset: 39) }
            }
        }
    }
}

/// Right after practising: Ayla writes the report, and you keep it with the application for this vacancy.
struct PracticeReportSheet: View {
    let vacancy: Vacancy
    let request: PracticeReportRequest
    let service: (any AylaService)?
    let name: String?
    let items: [VaultItem]
    let onDone: () -> Void

    @State private var report: PracticeReport?
    @State private var failed = false
    @State private var round = 0
    @State private var isKept = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let report {
                        PracticeReportView(report: report, vacancy: vacancy)
                    } else if failed {
                        VStack(spacing: 14) {
                            PaveInlineError(message: ApplyMessages.practiceReportFailed)
                            PaveSecondaryButton(title: PlanMessages.proposalAgain) { round += 1 }
                        }
                    } else {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(ApplyMessages.practiceReportWriting).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if report != nil {
                    PavePrimaryButton(title: isKept ? ApplyMessages.practiceKept : ApplyMessages.practiceKeep) { keep() }
                        .disabled(isKept)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                        .background(Color.canvas)
                }
            }
            .navigationTitle(ApplyMessages.practiceReportTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done, action: onDone) } }
            .task(id: round) { await load() }
        }
        .tint(.paveAccent)
    }

    private func load() async {
        failed = false
        guard let service else {
            failed = true
            return
        }
        do {
            report = try await service.practiceReport(request)
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    /// Kept with the application for this vacancy; when there is none yet, one starts, with your evidence in it.
    private func keep() {
        guard let report else { return }
        let store = ApplicationStore()
        var draft = store.load(vacancy.id) ?? ApplicationBuilder.draft(for: vacancy, items: items, name: name ?? "")
        draft.practice = (draft.practice ?? []) + [report]
        draft.updatedAt = .now
        store.save(draft)
        PaveHaptics.success()
        isKept = true
    }
}
