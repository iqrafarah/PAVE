import PAVECore
import SwiftUI

/// The demo invitation on Mijn sollicitatie: pick one of three moments, put it in your calendar, and get ready with a
/// short list and Ayla. Marked as a demo, since no real employer sent it.
struct ApplicationInvitationCard: View {
    let model: ApplicationStudioModel
    let invitation: ApplicationInvitation
    let onPractise: () -> Void

    @State private var showsCalendar = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    private var vacancy: Vacancy { model.draft.vacancy }
    private var steps: [ApplicationInvitation.PrepStep] { ApplicationInvitation.PrepStep.allCases }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(ApplyMessages.invitationTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(ApplyMessages.demo)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 22)
                    .background(Color.tileFill, in: .capsule)
                Spacer(minLength: 0)
            }
            if let chosen = invitation.chosen {
                planned(chosen)
            } else {
                Text(ApplyMessages.invitationText(vacancy))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    ForEach(invitation.slots, id: \.self) { slot in
                        Button {
                            PaveHaptics.success()
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { model.choose(slot) }
                        } label: {
                            HStack {
                                Image(.iconCalendarDaysSolid)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .paveIconFrame(16)
                                    .foregroundStyle(Color.paveAccent)
                                    .accessibilityHidden(true)
                                Text(ApplyMessages.slot(slot))
                                    .textStyle(.bodyMedium)
                                    .foregroundStyle(Color.ink)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(Color.canvas, in: .rect(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder, lineWidth: 1) }
                            .contentShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.pave)
                    }
                }
            }
            Text(ApplyMessages.invitationDemoNote)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.paveAccent.opacity(0.5), lineWidth: 1.5) }
        .onAppear { model.readInvitation() }
        .sheet(isPresented: $showsCalendar) {
            if let chosen = invitation.chosen {
                ApplicationCalendarEditor(vacancy: vacancy, deadline: chosen, isTalk: true) { showsCalendar = false }
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func planned(_ chosen: Date) -> some View {
        Text(ApplyMessages.talkPlanned(chosen))
            .textStyle(.bodyMedium)
            .foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
        PaveSecondaryButton(title: ApplyMessages.talkToCalendar, icon: .iconCalendarDaysSolid) { showsCalendar = true }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ApplyMessages.prepTitle).textStyle(.label).foregroundStyle(Color.ink)
                Spacer()
                Text(ApplyMessages.prepCount(invitation.done.count, of: steps.count))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .monospacedDigit()
            }
            ForEach(steps, id: \.self) { step in
                let isDone = invitation.done.contains(step)
                Button {
                    PaveHaptics.selection()
                    if step == .practise, !isDone { onPractise() }
                    model.setPrep(step, done: !isDone)
                } label: {
                    HStack(spacing: 12) {
                        PaveCheckbox(isOn: isDone)
                        Text(ApplyMessages.prep(step, vacancy))
                            .textStyle(.bodyMedium)
                            .foregroundStyle(isDone ? Color.inkMuted : Color.ink)
                            .strikethrough(isDone, color: Color.inkMuted)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityAddTraits(isDone ? .isSelected : [])
            }
        }
    }
}
