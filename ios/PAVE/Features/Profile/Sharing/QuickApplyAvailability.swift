import PAVECore
import SwiftUI

/// When you can work: the days as chips and the most hours a week. Kept for your next side-job application.
struct QuickApplyAvailability: View {
    @Binding var availability: Availability

    private let hours = [8, 12, 16, 20, 24, 32]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SharingMessages.availability).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).padding(.leading, 8)
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    ForEach(Availability.Day.allCases, id: \.self) { day in
                        chip(SharingMessages.day(day), isOn: availability.days.contains(day)) {
                            if let index = availability.days.firstIndex(of: day) {
                                availability.days.remove(at: index)
                            } else {
                                availability.days = Availability.Day.allCases.filter { availability.days.contains($0) || $0 == day }
                            }
                        }
                    }
                }
                Text(SharingMessages.maxHours).textStyle(.caption).foregroundStyle(Color.inkMuted)
                FlowLayout(spacing: 8) {
                    ForEach(hours, id: \.self) { value in
                        chip(SharingMessages.hours(value), isOn: availability.maxHours == value) {
                            availability.maxHours = availability.maxHours == value ? nil : value
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 14))
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            PaveHaptics.selection()
            action()
        } label: {
            Text(title)
                .textStyle(.chip)
                .foregroundStyle(isOn ? Color.white : Color.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(isOn ? Color.paveAccentFill : Color.canvas, in: .capsule)
                .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
                .frame(minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
