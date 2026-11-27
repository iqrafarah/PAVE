import PAVECore
import SwiftUI

/// Status, deadline and note of an application, all kept by hand.
struct ApplicationHubStatus: View {
    let model: ApplicationStudioModel

    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var remindersDenied = false
    @State private var showsCalendar = false

    private var deadline: Binding<Date> {
        Binding(get: { model.tracking.deadline ?? .now }, set: { model.setDeadline($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ApplyMessages.statusLabel)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                // All five in view, on a second line where the screen is narrow.
                FlowLayout(spacing: 8) {
                        ForEach(ApplicationStatus.allCases, id: \.self) { status in
                            let isOn = model.tracking.status == status
                            Button(ApplyMessages.status(status)) {
                                PaveHaptics.selection()
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { model.setStatus(status) }
                            }
                            .textStyle(.chip)
                            .foregroundStyle(isOn ? Color.white : Color.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(isOn ? Color.paveAccentFill : Color.canvas, in: .capsule)
                            .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
                            .frame(minHeight: 44)
                            .contentShape(.capsule)
                            .buttonStyle(.pave)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                }
                Text(ApplyMessages.statusHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Toggle(ApplyMessages.deadline, isOn: Binding(get: { model.tracking.deadline != nil }, set: { model.setDeadline($0 ? .now.addingTimeInterval(7 * 86_400) : nil) }))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .tint(.paveAccentFill)
                if model.tracking.deadline != nil {
                    DatePicker(ApplyMessages.deadline, selection: deadline, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, PaveLanguageStore.current.locale)
                        .fixedSize()
                }
            }
            .frame(minHeight: 44)
            if let found = model.suggestedDeadline {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ApplyMessages.foundDeadline)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                    Text("“\(found.quote)”")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(ApplyMessages.useDeadline(found.date)) { model.setDeadline(found.date) }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 44)
                        .buttonStyle(.pave)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
            }
            if let date = model.tracking.deadline {
                Button(ApplyMessages.addToCalendar) { showsCalendar = true }
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
                    .sheet(isPresented: $showsCalendar) {
                        ApplicationCalendarEditor(vacancy: model.draft.vacancy, deadline: date) { showsCalendar = false }
                            .ignoresSafeArea()
                    }
            }
            if let date = model.tracking.deadline, model.tracking.status == .concept {
                let distance = ApplicationDeadline.of(date, now: .now)
                Text(ApplyMessages.deadlineDistance(distance))
                    .textStyle(.caption)
                    .foregroundStyle(distance.isUrgent ? Color.critical : Color.inkMuted)
                    .accessibilityLabel(ApplyMessages.deadlineDistance(distance))
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle(ApplyMessages.remindMe, isOn: Binding(get: { model.tracking.remindsMe }, set: { isOn in
                    Task { remindersDenied = !(await model.setReminders(isOn)) }
                }))
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .tint(.paveAccentFill)
                .frame(minHeight: 44)
                Text(remindersDenied ? ApplyMessages.remindDenied : ApplyMessages.remindHint)
                    .textStyle(.caption)
                    .foregroundStyle(remindersDenied ? Color.critical : Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VaultFormField(title: ApplyMessages.note, isRequired: false, minHeight: 80) {
                TextField("", text: Binding(get: { model.tracking.note }, set: { model.setNote($0) }), prompt: Text(ApplyMessages.notePrompt).foregroundStyle(Color.inkMuted), axis: .vertical)
                    .lineLimit(2...6)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}

extension ApplicationDeadline {
    /// Overdue, today or tomorrow: worth a second look.
    var isUrgent: Bool {
        switch self {
        case .overdue, .today: true
        case .upcoming(let days): days <= 1
        }
    }
}
