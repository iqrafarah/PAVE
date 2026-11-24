import PAVECore
import SwiftUI

/// Status, deadline and note of an application, all kept by hand.
struct ApplicationHubStatus: View {
    let model: ApplicationStudioModel

    @Environment(\.paveReduceMotion) private var reduceMotion

    private var deadline: Binding<Date> {
        Binding(get: { model.tracking.deadline ?? .now }, set: { model.setDeadline($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ApplyMessages.statusLabel)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
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
                }
                .scrollIndicators(.hidden)
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
                        .environment(\.locale, Locale(identifier: "nl_NL"))
                        .fixedSize()
                }
            }
            .frame(minHeight: 44)
            VaultFormField(title: ApplyMessages.note, isRequired: false, minHeight: 80) {
                TextField("", text: Binding(get: { model.tracking.note }, set: { model.setNote($0) }), prompt: Text(ApplyMessages.notePrompt).foregroundStyle(Color.inkMuted), axis: .vertical)
                    .lineLimit(2...6)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}
