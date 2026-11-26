import PAVECore
import SwiftUI

/// When you can work: the seven days as equal cells in one row, the most hours a week in a tidy grid, and one line that
/// says back what you chose. Kept for your next side-job application.
struct QuickApplyAvailability: View {
    @Binding var availability: Availability

    private let hours = [8, 12, 16, 20, 24, 32]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SharingMessages.availability).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).padding(.leading, 8)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(Availability.Day.allCases, id: \.self) { day in
                        cell(SharingMessages.day(day), isOn: availability.days.contains(day)) { toggle(day) }
                            .accessibilityLabel(day.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(SharingMessages.maxHours).textStyle(.caption).foregroundStyle(Color.inkMuted)
                    // Three across on a phone, all six on one row where there is room: never a lone one on its own line.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                        ForEach(hours, id: \.self) { value in
                            cell(SharingMessages.hours(value), isOn: availability.maxHours == value) {
                                availability.maxHours = availability.maxHours == value ? nil : value
                            }
                        }
                    }
                }
                Text(SharingMessages.availabilitySummary(availability))
                    .textStyle(.caption)
                    .foregroundStyle(availability.isEmpty ? Color.inkMuted : Color.paveAccent)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: availability)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 14))
        }
    }

    /// Kept in the order of the week, whatever order they were tapped in.
    private func toggle(_ day: Availability.Day) {
        if let index = availability.days.firstIndex(of: day) {
            availability.days.remove(at: index)
        } else {
            availability.days = Availability.Day.allCases.filter { availability.days.contains($0) || $0 == day }
        }
    }

    private func cell(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            PaveHaptics.selection()
            action()
        } label: {
            Text(title)
                .textStyle(.chip)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isOn ? Color.white : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isOn ? Color.paveAccentFill : Color.canvas, in: .rect(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
                .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var availability = Availability(days: [.dinsdag, .zaterdag], maxHours: 12)
    QuickApplyAvailability(availability: $availability)
        .padding()
        .background(Color.canvas)
}
